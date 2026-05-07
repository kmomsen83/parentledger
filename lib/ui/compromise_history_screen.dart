import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../models/negotiation_proposal.dart';
import '../providers/case_context.dart';
import '../services/proposal_service.dart';
import 'legal_export_center_screen.dart';
import 'proposal_detail_screen.dart';
import 'recent_activity_timeline_screen.dart';

/// Negotiation outcomes for the active case — sourced from `proposals` via [ProposalService].
class CompromiseHistoryScreen extends StatelessWidget {
  const CompromiseHistoryScreen({super.key});

  static DateTime _activityDate(NegotiationProposal p) {
    return p.finalizedAt ??
        p.rejectedAt ??
        p.acceptedAt ??
        p.negotiatingStartedAt ??
        p.createdAt;
  }

  static String _kindLabel(String kind) {
    switch (kind) {
      case 'schedule':
        return 'Schedule';
      case 'expense':
        return 'Expense';
      case 'location':
        return 'Location';
      default:
        return kind.isEmpty ? 'Proposal' : kind;
    }
  }

  static Color _statusAccent(String status) {
    switch (status) {
      case ProposalStatuses.finalized:
      case ProposalStatuses.accepted:
        return PLDesign.success;
      case ProposalStatuses.rejected:
        return PLDesign.danger;
      case ProposalStatuses.pending:
      case ProposalStatuses.negotiating:
        return PLDesign.warning;
      default:
        return PLDesign.textMuted;
    }
  }

  static String _statusLabel(NegotiationProposal p) {
    switch (p.status) {
      case ProposalStatuses.finalized:
        return 'Finalized';
      case ProposalStatuses.accepted:
        return 'Accepted';
      case ProposalStatuses.rejected:
        return 'Rejected';
      case ProposalStatuses.pending:
        return 'Pending';
      case ProposalStatuses.negotiating:
        return 'In discussion';
      default:
        return p.status.isEmpty ? 'Unknown' : p.status;
    }
  }

  static String _insight({
    required List<NegotiationProposal> list,
    required int finalized,
    required int rejected,
    required int open,
  }) {
    if (list.isEmpty) {
      return 'Create negotiation proposals from Proposals to build history here. '
          'Each outcome is logged on your case timeline.';
    }
    if (rejected >= 3 && finalized > 0 && rejected > finalized * 2) {
      return 'Rejections are elevated versus finalized agreements. '
          'Try smaller, specific asks and review framing in the AI Fairness Engine.';
    }
    if (finalized > 0 && rejected == 0 && open == 0) {
      return 'All recorded negotiations in this view reached a finalized agreement—strong documentation for your file.';
    }
    if (open > 0 && finalized + rejected == 0) {
      return 'You have open negotiations. Continue in Proposals to accept, revise, or finalize terms.';
    }
    if (finalized > 0) {
      return 'Finalized proposals are part of your court-ready record. '
          'Accepted terms should be finalized when both parents are aligned.';
    }
    return 'Statuses mirror Firestore proposals and the case ledger—tap a row for full detail.';
  }

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId?.trim();
    final hasCase = caseId != null && caseId.isNotEmpty;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Compromise history'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
      ),
      body: !hasCase
            ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No case is linked to your profile yet. '
                  'Complete setup to view negotiation history.',
                  style: PLDesign.body.copyWith(
                    color: PLDesign.textMuted,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
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
                        'Could not load proposals: ${snap.error}',
                        style: PLDesign.body.copyWith(color: PLDesign.danger),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = List<NegotiationProposal>.from(snap.data ?? []);
                list.sort((a, b) => _activityDate(b).compareTo(_activityDate(a)));

                var finalized = 0;
                var rejected = 0;
                var open = 0;
                for (final p in list) {
                  if (p.status == ProposalStatuses.finalized) {
                    finalized++;
                  } else if (p.status == ProposalStatuses.rejected) {
                    rejected++;
                  } else {
                    open++;
                  }
                }

                final settled = finalized + rejected;
                final agreementPct = settled > 0
                    ? ((finalized / settled) * 100).round()
                    : null;

                final dateFmt = DateFormat.yMMMd();

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xff4A6CF7), Color(0xff7A8BFF)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: PLDesign.softShadow,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.handshake_rounded,
                              color: Colors.white, size: 34),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tTone('compromiseHealth'),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  settled == 0
                                      ? '—'
                                      : '$agreementPct%',
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  settled == 0
                                      ? 'No finalized vs rejected outcomes yet'
                                      : 'Finalized share among settled proposals',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.balance_rounded,
                              color: Colors.white.withValues(alpha: 0.9)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            label: 'Finalized',
                            value: '$finalized',
                            color: PLDesign.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            label: 'Rejected',
                            value: '$rejected',
                            color: PLDesign.danger,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            label: 'Open',
                            value: '$open',
                            color: PLDesign.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Negotiation timeline',
                      style: PLDesign.sectionTitle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Newest first · same data as Proposals',
                      style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                    ),
                    const SizedBox(height: 12),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No proposals for this case yet.',
                          style: PLDesign.body.copyWith(color: PLDesign.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...list.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: PLDesign.card,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ProposalDetailScreen(proposalId: p.id),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 40,
                                      width: 40,
                                      decoration: BoxDecoration(
                                        color: _statusAccent(p.status)
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.handshake_rounded,
                                        color: _statusAccent(p.status),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.title.isEmpty
                                                ? 'Untitled proposal'
                                                : p.title,
                                            style: PLDesign.sectionTitle
                                                .copyWith(fontSize: 16),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_kindLabel(p.kind)} · ${p.childName.trim().isEmpty ? 'Child' : p.childName}',
                                            style: PLDesign.caption,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            dateFmt.format(
                                              _activityDate(p).toLocal(),
                                            ),
                                            style: PLDesign.caption.copyWith(
                                              color: PLDesign.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _statusLabel(p),
                                      style: PLDesign.caption.copyWith(
                                        color: _statusAccent(p.status),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PLDesign.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PLDesign.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline_rounded,
                                  color: PLDesign.ai, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Insight',
                                style: PLDesign.sectionTitle.copyWith(fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _insight(
                              list: list,
                              finalized: finalized,
                              rejected: rejected,
                              open: open,
                            ),
                            style: PLDesign.caption.copyWith(
                              height: 1.45,
                              color: PLDesign.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const RecentActivityTimelineScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.timeline_rounded),
                            label: const Text('Case timeline'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: PLDesign.textPrimary,
                              side: const BorderSide(color: PLDesign.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const LegalExportCenterScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.file_download_outlined),
                            label: const Text('Exports'),
                            style: FilledButton.styleFrom(
                              backgroundColor: PLDesign.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
    );
  }

  static Widget _statCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PLDesign.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: PLDesign.statNumber.copyWith(
              fontSize: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: PLDesign.caption.copyWith(
              color: PLDesign.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
