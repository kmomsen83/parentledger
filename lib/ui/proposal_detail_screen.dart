import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';
import '../models/negotiation_proposal.dart';
import '../services/proposal_service.dart';
import '../services/timeline_actor_resolver.dart';
import 'active_negotiation_screen.dart';
import 'proposal_resolution_screen.dart';
import 'widgets/proposal_data_compare.dart';

class ProposalDetailScreen extends StatelessWidget {
  const ProposalDetailScreen({
    super.key,
    required this.proposalId,
  });

  final String proposalId;

  String _statusDisplay(String raw) {
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  Future<void> _confirmReject(BuildContext context, NegotiationProposal p) async {
    final reason = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: const Text(
          'Reject proposal',
          style: TextStyle(color: PLDesign.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This records your rejection in the case ledger. Optional note:',
              style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLines: 3,
              style: const TextStyle(color: PLDesign.textPrimary),
              decoration: InputDecoration(
                hintText: 'Reason for rejection',
                hintStyle: TextStyle(color: PLDesign.textMuted.withValues(alpha: 0.8)),
                filled: true,
                fillColor: PLDesign.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: PLDesign.danger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    try {
      await ProposalService.reject(p, reason: reason.text);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposal rejected and logged')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reject: $e')),
      );
    }
  }

  Future<void> _confirmAccept(BuildContext context, NegotiationProposal p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: const Text(
          'Accept proposal',
          style: TextStyle(color: PLDesign.textPrimary),
        ),
        content: Text(
          'Accepting records agreement with the current proposed terms (revision ${p.proposedRevision}).',
          style: PLDesign.body.copyWith(color: PLDesign.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ProposalService.accept(p);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposal accepted')),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProposalResolutionScreen(proposalId: proposalId),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Proposal'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<NegotiationProposal?>(
        stream: ProposalService.watchProposal(proposalId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data;
          if (p == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'This proposal is no longer available or you do not have access.',
                  textAlign: TextAlign.center,
                  style: PLDesign.body.copyWith(color: PLDesign.textMuted),
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(p.title, style: PLDesign.sectionTitle),
                const SizedBox(height: 10),
                FutureBuilder<TimelineActor>(
                  future: TimelineActor.load(p.createdBy),
                  builder: (context, actorSnap) {
                    final name = actorSnap.data?.fullName ?? 'Participant';
                    return Text(
                      'Logged by $name · ${_statusDisplay(p.status)} · ${df.format(p.createdAt.toLocal())}',
                      style: PLDesign.caption.copyWith(color: PLDesign.textMuted, height: 1.35),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Child: ${p.childName}',
                  style: PLDesign.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PLDesign.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PLDesign.border),
                    boxShadow: PLDesign.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terms comparison',
                        style: PLDesign.caption.copyWith(
                          color: PLDesign.textMuted,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ProposalDataCompare(
                        before: p.originalData,
                        after: p.proposedData,
                      ),
                    ],
                  ),
                ),
                if ((p.summary ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: PLDesign.aiSurface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: PLDesign.ai, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Summary',
                              style: PLDesign.caption.copyWith(
                                color: PLDesign.ai,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.summary!.trim(),
                          style: PLDesign.body.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                if (p.status == ProposalStatuses.accepted ||
                    p.status == ProposalStatuses.finalized)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProposalResolutionScreen(proposalId: proposalId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.gavel_rounded),
                    label: Text(
                      p.status == ProposalStatuses.finalized
                          ? 'View finalized record'
                          : 'View agreement',
                    ),
                  ),
                if (p.canNegotiate) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () async {
                      if (p.status == ProposalStatuses.pending) {
                        try {
                          await ProposalService.startNegotiation(p);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open negotiation: $e')),
                          );
                          return;
                        }
                      }
                      if (!context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ActiveNegotiationScreen(proposalId: proposalId),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(backgroundColor: PLDesign.primary),
                    icon: const Icon(Icons.forum_rounded),
                    label: const Text('Open negotiation'),
                  ),
                ],
                if (p.canAcceptOrReject) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmReject(context, p),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _confirmAccept(context, p),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
