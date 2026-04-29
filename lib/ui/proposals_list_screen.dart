import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentledger/design/design.dart';
import 'package:provider/provider.dart';

import '../models/negotiation_proposal.dart';
import '../providers/case_context.dart';
import '../services/ai_service.dart';
import '../services/proposal_service.dart';
import 'active_negotiation_screen.dart';
import 'create_proposal_screen.dart';
import 'proposal_detail_screen.dart';
import 'proposal_resolution_screen.dart';

class ProposalsListScreen extends StatefulWidget {
  const ProposalsListScreen({super.key});

  @override
  State<ProposalsListScreen> createState() => _ProposalsListScreenState();
}

class _ProposalsListScreenState extends State<ProposalsListScreen> {
  final Map<String, Map<String, dynamic>> _aiFairnessById = {};
  final Set<String> _aiFairnessLoading = {};

  String _filter = 'All';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _primeAiForList(List<NegotiationProposal> list) async {
    for (final p in list) {
      if (!mounted) return;
      await _runAiFairness(p);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case ProposalStatuses.accepted:
      case ProposalStatuses.finalized:
        return PLDesign.success;
      case ProposalStatuses.negotiating:
      case ProposalStatuses.pending:
        return PLDesign.warning;
      case ProposalStatuses.rejected:
        return PLDesign.danger;
      default:
        return PLDesign.textMuted;
    }
  }

  String _statusDisplay(NegotiationProposal p) {
    final s = p.status;
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Color _fairnessColor(String fairness) {
    switch (fairness) {
      case 'Needs Review':
        return PLDesign.danger;
      case 'Balanced':
        return PLDesign.warning;
      default:
        return PLDesign.success;
    }
  }

  Color _fairnessBadgeColor(String result) {
    switch (result) {
      case 'fair':
        return PLDesign.success;
      case 'balanced':
        return PLDesign.warning;
      case 'unfair':
        return PLDesign.danger;
      default:
        return PLDesign.textMuted;
    }
  }

  String _proposalTextForAi(NegotiationProposal p) {
    return 'Title: ${p.title}\nChild: ${p.childName}\nStatus: ${p.status}\n'
        'Kind: ${p.kind}\nSummary: ${p.summary ?? ""}';
  }

  Future<void> _runAiFairness(NegotiationProposal p) async {
    if (_aiFairnessLoading.contains(p.id)) return;
    final text = _proposalTextForAi(p);
    if (text.trim().length < 8) return;
    setState(() => _aiFairnessLoading.add(p.id));
    try {
      final cached = await AiService.peekFairnessCache(text);
      if (!mounted) return;
      if (cached != null) {
        setState(() => _aiFairnessById[p.id] = cached);
      }
      final r = await AiService.analyzeFairness(text);
      if (!mounted) return;
      setState(() => _aiFairnessById[p.id] = r);
      if (r['_insightsUnavailable'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AiService.insightsUnavailableMessage)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AiService.userFacingMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _aiFairnessLoading.remove(p.id));
      }
    }
  }

  void _openDetail(String proposalId) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProposalDetailScreen(proposalId: proposalId),
      ),
    );
  }

  void _openNegotiation(String proposalId) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ActiveNegotiationScreen(proposalId: proposalId),
      ),
    );
  }

  void _openResolution(String proposalId) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProposalResolutionScreen(proposalId: proposalId),
      ),
    );
  }

  List<NegotiationProposal> _filterList(List<NegotiationProposal> all) {
    if (_filter == 'Needs attention') {
      return all
          .where(
            (p) =>
                p.status == ProposalStatuses.pending ||
                p.status == ProposalStatuses.negotiating,
          )
          .toList();
    }
    if (_filter == 'Accepted') {
      return all
          .where(
            (p) =>
                p.status == ProposalStatuses.accepted ||
                p.status == ProposalStatuses.finalized,
          )
          .toList();
    }
    return all;
  }

  Widget _filterChip(String label) {
    final selected = _filter == label;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = label),
      selectedColor: PLDesign.primary.withValues(alpha: 0.25),
      backgroundColor: PLDesign.card,
      labelStyle: TextStyle(
        color: selected ? Colors.white : PLDesign.textMuted,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: selected ? PLDesign.primary : PLDesign.border,
        ),
      ),
    );
  }

  Widget _proposalCard(NegotiationProposal p) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final statusLabel = _statusDisplay(p);
    final createdLabel = DateFormat.yMMMd().add_jm().format(p.createdAt.toLocal());
    final ai = _aiFairnessById[p.id];
    final aiLoading = _aiFairnessLoading.contains(p.id);
    final resultLabel = ai == null ? null : (ai['result'] ?? '').toString();
    final scoreLabel = ai == null
        ? null
        : (ai['score'] is num ? (ai['score'] as num).toStringAsFixed(0) : '');
    final needsAttention = p.status == ProposalStatuses.pending ||
        p.status == ProposalStatuses.negotiating;
    final otherPartyTurn =
        p.createdBy.isNotEmpty && p.createdBy != uid && needsAttention;
    final aiLineColor = ai == null
        ? _fairnessColor('Balanced')
        : _fairnessBadgeColor(resultLabel ?? '');
    final fairnessFallback =
        otherPartyTurn ? 'Needs Review' : 'Balanced';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: needsAttention
              ? PLDesign.warning.withValues(alpha: 0.55)
              : PLDesign.border,
          width: needsAttention ? 1.4 : 1,
        ),
        boxShadow: PLDesign.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: PLDesign.primaryGradient,
                ),
                child: Center(
                  child: Text(
                    p.childName.isNotEmpty ? p.childName[0] : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: PLDesign.timelineTitle),
                    const SizedBox(height: 3),
                    Text('Child: ${p.childName}', style: PLDesign.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor(p.status).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _statusColor(p.status).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: _statusColor(p.status),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(createdLabel, style: PLDesign.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: PLDesign.aiSurface,
            child: Row(
              children: [
                const Icon(Icons.psychology_alt_rounded,
                    color: PLDesign.ai, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resultLabel == null
                            ? (aiLoading
                                ? 'AI fairness: analyzing…'
                                : 'AI fairness: tap refresh to analyze')
                            : 'AI fairness: $resultLabel · score $scoreLabel',
                        style: TextStyle(
                          color: ai == null
                              ? _fairnessColor(fairnessFallback)
                              : aiLineColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (ai != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          (ai['reasoning'] ?? '').toString(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: PLDesign.caption.copyWith(
                            color: PLDesign.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Run AI fairness',
                  onPressed: aiLoading ? null : () => _runAiFairness(p),
                  icon: aiLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, color: PLDesign.ai),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openDetail(p.id),
                  child: const Text('View details'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (p.status == ProposalStatuses.accepted ||
                        p.status == ProposalStatuses.finalized) {
                      _openResolution(p.id);
                    } else {
                      _openNegotiation(p.id);
                    }
                  },
                  child: Text(
                    (p.status == ProposalStatuses.accepted ||
                            p.status == ProposalStatuses.finalized)
                        ? 'Agreement'
                        : (needsAttention ? 'Respond' : 'Open thread'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId?.trim();
    final hasCase = caseId != null && caseId.isNotEmpty;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Proposals'),
        backgroundColor: PLDesign.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CreateProposalScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: !hasCase
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Open a case from your profile to load co-parent proposals.',
                  textAlign: TextAlign.center,
                  style: PLDesign.body.copyWith(color: PLDesign.textMuted),
                ),
              ),
            )
          : StreamBuilder<List<NegotiationProposal>>(
              stream: ProposalService.watchProposalsForCase(caseId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load proposals.',
                        style: PLDesign.body.copyWith(color: PLDesign.danger),
                      ),
                    ),
                  );
                }
                final all = snap.data ?? [];
                if (snap.connectionState == ConnectionState.waiting &&
                    all.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (all.isNotEmpty) _primeAiForList(all);
                });

                final visible = _filterList(all);
                final attentionCount = all
                    .where(
                      (p) =>
                          p.status == ProposalStatuses.pending ||
                          p.status == ProposalStatuses.negotiating,
                    )
                    .length;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: PLDesign.elevatedCard,
                      child: Row(
                        children: [
                          const Icon(Icons.handshake_rounded,
                              color: PLDesign.primary, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Negotiation overview',
                                  style: PLDesign.sectionTitle,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  attentionCount == 0
                                      ? 'No open negotiations'
                                      : '$attentionCount open negotiation${attentionCount == 1 ? '' : 's'}',
                                  style: PLDesign.caption.copyWith(
                                    color: attentionCount > 0
                                        ? PLDesign.warning
                                        : PLDesign.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (all.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.edit_document,
                              size: 44,
                              color: PLDesign.textMuted.withValues(alpha: 0.45),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No proposals yet',
                              style: PLDesign.sectionTitle.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a schedule, expense, or location proposal to start a documented negotiation.',
                              textAlign: TextAlign.center,
                              style: PLDesign.caption.copyWith(
                                color: PLDesign.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (all.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _filterChip('All'),
                          _filterChip('Needs attention'),
                          _filterChip('Accepted'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...visible.map(_proposalCard),
                    ],
                  ],
                );
              },
            ),
    );
  }
}
