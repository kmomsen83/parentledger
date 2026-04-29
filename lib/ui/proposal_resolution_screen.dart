import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../design/design.dart';
import '../models/negotiation_proposal.dart';
import '../services/proposal_pdf_service.dart';
import '../services/proposal_service.dart';
import '../services/timeline_actor_resolver.dart';
import 'widgets/proposal_data_compare.dart';

class ProposalResolutionScreen extends StatefulWidget {
  const ProposalResolutionScreen({
    super.key,
    required this.proposalId,
  });

  final String proposalId;

  @override
  State<ProposalResolutionScreen> createState() =>
      _ProposalResolutionScreenState();
}

class _ProposalResolutionScreenState extends State<ProposalResolutionScreen> {
  bool _exporting = false;

  Future<String> _caseTitle(String caseId) async {
    final s =
        await FirebaseFirestore.instance.collection('cases').doc(caseId).get();
    final m = s.data();
    if (m == null) return 'Case';
    final t = (m['title'] ?? m['displayName'] ?? m['name'] ?? '').toString().trim();
    return t.isNotEmpty ? t : 'Case';
  }

  Future<void> _exportPdf(NegotiationProposal p) async {
    setState(() => _exporting = true);
    try {
      final caseTitle = await _caseTitle(p.caseId);
      final messages = await ProposalService.watchMessages(p.id).first;
      final pdf = await ProposalPdfService.buildNegotiationRecordPdf(
        proposal: p,
        caseTitle: caseTitle,
        messagesOldestFirst: messages,
      );
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: pdf,
        filename:
            'ParentLedger_proposal_${p.id}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _finalize(NegotiationProposal p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: const Text(
          'Finalize record',
          style: TextStyle(color: PLDesign.textPrimary),
        ),
        content: Text(
          'Finalizing locks this proposal as a permanent agreement record in the ledger.',
          style: PLDesign.body.copyWith(color: PLDesign.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ProposalService.finalizeRecord(p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record finalized')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not finalize: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Agreement'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<NegotiationProposal?>(
        stream: ProposalService.watchProposal(widget.proposalId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data;
          if (p == null) {
            return Center(
              child: Text(
                'Proposal not found.',
                style: PLDesign.body.copyWith(color: PLDesign.textMuted),
              ),
            );
          }

          if (p.status != ProposalStatuses.accepted &&
              p.status != ProposalStatuses.finalized) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Open this screen after both parties accept the proposed terms.',
                  textAlign: TextAlign.center,
                  style: PLDesign.body.copyWith(color: PLDesign.textMuted),
                ),
              ),
            );
          }

          final locked = p.status == ProposalStatuses.finalized;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PLDesign.success.withValues(alpha: 0.2),
                      PLDesign.card,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: PLDesign.success.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_rounded, color: PLDesign.success, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            locked ? 'Finalized agreement' : 'Accepted — finalize when ready',
                            style: PLDesign.sectionTitle.copyWith(fontSize: 19),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p.title,
                      style: PLDesign.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Child: ${p.childName}',
                      style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Final terms',
                style: PLDesign.caption.copyWith(
                  color: PLDesign.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              IgnorePointer(
                ignoring: true,
                child: Opacity(
                  opacity: 0.95,
                  child: ProposalDataCompare(
                    before: p.originalData,
                    after: p.proposedData,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Timestamps',
                style: PLDesign.caption.copyWith(
                  color: PLDesign.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              _stampTile(
                'Proposal created',
                df.format(p.createdAt.toLocal()),
              ),
              if (p.negotiatingStartedAt != null)
                _stampTile(
                  'Negotiation opened',
                  df.format(p.negotiatingStartedAt!.toLocal()),
                ),
              if (p.acceptedAt != null && p.acceptedBy != null && p.acceptedBy!.isNotEmpty)
                FutureBuilder<TimelineActor>(
                  future: TimelineActor.load(p.acceptedBy!),
                  builder: (context, asnap) {
                    final name = asnap.data?.fullName ?? 'Participant';
                    return _stampTile(
                      'Accepted · $name',
                      df.format(p.acceptedAt!.toLocal()),
                    );
                  },
                )
              else if (p.acceptedAt != null)
                _stampTile(
                  'Accepted',
                  df.format(p.acceptedAt!.toLocal()),
                ),
              if (p.finalizedAt != null)
                _stampTile(
                  'Record finalized',
                  df.format(p.finalizedAt!.toLocal()),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _exporting ? null : () => _exportPdf(p),
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(_exporting ? 'Preparing…' : 'Export to PDF'),
                style: FilledButton.styleFrom(
                  backgroundColor: PLDesign.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (p.canFinalize && !locked) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _finalize(p),
                  icon: const Icon(Icons.lock_rounded),
                  label: const Text('Finalize agreement record'),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  locked
                      ? 'This record is locked. Use PDF export for filings or counsel packets.'
                      : 'Finalize when the written agreement is complete. Export remains available after acceptance.',
                  style: PLDesign.caption.copyWith(color: PLDesign.textMuted, height: 1.35),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stampTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PLDesign.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: PLDesign.caption.copyWith(
                color: PLDesign.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: PLDesign.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
