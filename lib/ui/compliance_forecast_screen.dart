import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../models/exchange_model.dart';
import '../models/negotiation_proposal.dart';
import '../providers/case_context.dart';
import '../services/custody_risk_insights_service.dart';
import '../services/exchange_service.dart';
import '../services/proposal_service.dart';
import 'legal_export_center_screen.dart';
import 'recent_activity_timeline_screen.dart';

/// Forward-looking view derived from **`cases/{caseId}/insights/risk`** (same engine as custody risk)
/// plus upcoming exchanges and proposal outcomes.
class ComplianceForecastScreen extends StatelessWidget {
  const ComplianceForecastScreen({super.key});

  static const _horizonDays = 14;

  static Map<String, dynamic> _factorsOf(Map<String, dynamic>? data) {
    final raw = data?['factors'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  /// 0–1 intensity for progress bars (higher = more concern).
  static double _messageRiskBar(int flagged) =>
      (flagged / 8.0).clamp(0.0, 1.0);

  static double _exchangeRiskBar(int missed, int late) =>
      ((missed * 0.22) + (late * 0.14)).clamp(0.0, 1.0);

  static double _expenseRiskBar(int unpaid) =>
      (unpaid / 10.0).clamp(0.0, 1.0);

  static double _proposalFrictionBar(List<NegotiationProposal> proposals) {
    if (proposals.isEmpty) return 0;
    var rej = 0;
    var outcomes = 0;
    for (final p in proposals) {
      if (p.status == ProposalStatuses.rejected) {
        rej++;
        outcomes++;
      } else if (p.status == ProposalStatuses.finalized ||
          p.status == ProposalStatuses.accepted) {
        outcomes++;
      }
    }
    if (outcomes == 0) return 0;
    return (rej / outcomes).clamp(0.0, 1.0);
  }

  static String _insight({
    required String? riskLevel,
    required String? riskTrend,
    required int flagged,
    required int missed,
    required int unpaid,
  }) {
    final level = (riskLevel ?? '').toLowerCase();
    if (level == 'high') {
      return 'Risk score is elevated. Focus on timely exchanges, resolving open expenses, '
          'and neutral messaging—the same signals feed your custody risk insight doc.';
    }
    if (level == 'low') {
      return 'Stress indicators from documented activity are relatively low. '
          'Continue confirming exchanges and clearing unpaid items.';
    }
    if (missed > 0 || flagged > 3) {
      return 'Moderate concern: address missed or flagged items before they accumulate in the ledger.';
    }
    if (unpaid > 2) {
      return 'Several unpaid expense records remain—settling them reduces financial friction risk.';
    }
    final t = (riskTrend ?? 'stable').toLowerCase();
    if (t == 'up') {
      return 'Risk score ticked up versus the prior snapshot. Review upcoming exchanges and open expenses.';
    }
    if (t == 'down') {
      return 'Risk score improved from the last refresh—keep documenting completions and payments.';
    }
    return 'Figures come from `insights/risk` (refreshed with messaging, exchanges, expenses, and check-ins). '
        'Tap refresh to recompute from live case data.';
  }

  static List<ExchangeModel> _upcomingWindow(
    List<ExchangeModel> all, {
    required DateTime now,
  }) {
    final horizon = now.add(const Duration(days: _horizonDays));
    return all
        .where((e) => !e.scheduledTime.isAfter(horizon))
        .take(6)
        .toList();
  }

  static Color _windowColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return PLDesign.danger;
      case 'moderate':
        return PLDesign.warning;
      default:
        return PLDesign.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId?.trim();
    final hasCase = caseId != null && caseId.isNotEmpty;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Compliance forecast'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        actions: hasCase
            ? [
                IconButton(
                  tooltip: 'Refresh risk insights',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () async {
                    await CustodyRiskInsightsService.refresh(caseId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Compliance factors refreshed from case data'),
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: !hasCase
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No case is linked to your profile yet. '
                  'Complete setup to view compliance forecasts.',
                  style: PLDesign.body.copyWith(
                    color: PLDesign.textMuted,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : StreamBuilder(
              stream: CustodyRiskInsightsService.watchRisk(caseId),
              builder: (context, riskSnap) {
                return StreamBuilder<List<ExchangeModel>>(
                  stream: ExchangeService.watchUpcoming(caseId),
                  builder: (context, exSnap) {
                    return StreamBuilder<List<NegotiationProposal>>(
                      stream: ProposalService.watchProposalsForCase(caseId),
                      builder: (context, propSnap) {
                        if (riskSnap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Could not load insights: ${riskSnap.error}',
                                style: PLDesign.body.copyWith(color: PLDesign.danger),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final data = riskSnap.data?.data();
                        final riskScore = (data?['riskScore'] as num?)?.toInt();
                        final riskLevel =
                            data?['riskLevel']?.toString() ?? '—';
                        final riskTrend =
                            data?['riskTrend']?.toString() ?? 'stable';

                        final projected = riskScore != null
                            ? (100 - riskScore).clamp(0, 100)
                            : null;

                        final factors = _factorsOf(data);
                        final flagged =
                            (factors['flaggedMessages'] as num?)?.toInt() ?? 0;
                        final missed =
                            (factors['missedExchanges'] as num?)?.toInt() ?? 0;
                        final late =
                            (factors['lateExchangeCheckIns'] as num?)?.toInt() ??
                                0;
                        final unpaid =
                            (factors['unpaidExpenses'] as num?)?.toInt() ?? 0;

                        final msgBar = _messageRiskBar(flagged);
                        final exBar = _exchangeRiskBar(missed, late);
                        final finBar = _expenseRiskBar(unpaid);

                        final proposals = propSnap.data ?? [];
                        final propBar = _proposalFrictionBar(proposals);

                        final now = DateTime.now();
                        final upcoming = _upcomingWindow(
                          exSnap.data ?? [],
                          now: now,
                        );

                        final dateFmt = DateFormat.yMMMd().add_jm();

                        return ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff0ea5e9),
                                    Color(0xff2563eb),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: PLDesign.softShadow,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.auto_graph_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Projected compliance',
                                          style: TextStyle(
                                            color:
                                                Colors.white.withValues(alpha: 0.85),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          projected == null
                                              ? '—'
                                              : '$projected%',
                                          style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          projected == null
                                              ? 'Open messaging & exchanges to populate risk insights'
                                              : '100 − custody risk score ($riskScore)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white
                                                .withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        riskLevel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        riskTrend,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.75),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Based on `cases/$caseId/insights/risk`. '
                              'Informational only—not legal advice.',
                              style: PLDesign.caption.copyWith(height: 1.35),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              context.tTone('complianceFactors'),
                              style: PLDesign.sectionTitle.copyWith(fontSize: 17),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Higher bars = more documented friction in that area.',
                              style: PLDesign.caption.copyWith(
                                color: PLDesign.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _forecastBar(
                              context,
                              label: 'Messaging flags (tone / compliance labels)',
                              value: msgBar,
                              color: PLDesign.warning,
                            ),
                            _forecastBar(
                              context,
                              label: 'Exchange timing (missed + late check-ins)',
                              value: exBar,
                              color: PLDesign.danger,
                            ),
                            _forecastBar(
                              context,
                              label: 'Open expenses (unpaid count)',
                              value: finBar,
                              color: PLDesign.warning,
                            ),
                            _forecastBar(
                              context,
                              label: 'Proposal friction (rejections / outcomes)',
                              value: propBar,
                              color: PLDesign.primary,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Upcoming focus ($_horizonDays days)',
                              style: PLDesign.sectionTitle.copyWith(fontSize: 17),
                            ),
                            const SizedBox(height: 10),
                            if (upcoming.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'No scheduled exchanges in the next $_horizonDays days.',
                                  style: PLDesign.body.copyWith(
                                    color: PLDesign.textMuted,
                                  ),
                                ),
                              )
                            else
                              ...upcoming.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: PLDesign.card,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: PLDesign.border),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.event_rounded,
                                          color: _windowColor(riskLevel),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                e.locationName.trim().isEmpty
                                                    ? 'Custody exchange'
                                                    : e.locationName.trim(),
                                                style: PLDesign.sectionTitle
                                                    .copyWith(fontSize: 15),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                dateFmt.format(
                                                  e.scheduledTime.toLocal(),
                                                ),
                                                style: PLDesign.caption.copyWith(
                                                  color: PLDesign.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          e.status,
                                          style: PLDesign.caption.copyWith(
                                            color: PLDesign.textMuted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
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
                                      Icon(
                                        Icons.lightbulb_outline_rounded,
                                        color: PLDesign.ai,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Insight',
                                        style: PLDesign.sectionTitle
                                            .copyWith(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _insight(
                                      riskLevel: riskLevel == '—'
                                          ? null
                                          : riskLevel,
                                      riskTrend: riskTrend,
                                      flagged: flagged,
                                      missed: missed,
                                      unpaid: unpaid,
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
                                      side: const BorderSide(
                                        color: PLDesign.border,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  static Widget _forecastBar(
    BuildContext context, {
    required String label,
    required double value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: PLDesign.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: PLDesign.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: PLDesign.surface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
