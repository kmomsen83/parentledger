import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:parentledger/design/design.dart';
import 'package:parentledger/models/court_summary_document.dart';
import 'package:parentledger/providers/case_context.dart';
import 'package:parentledger/services/court_pdf_service.dart';
import 'package:parentledger/services/court_summary_documents_service.dart';
import 'package:parentledger/ui/pdf_preview_screen.dart';
import 'package:parentledger/ui/widgets/premium_locked_tap.dart';
import 'package:parentledger/ui/widgets/premium_teaser_shell.dart';
import 'package:parentledger/ui/widgets/premium_upgrade_sheet.dart';

class CustodyRiskScreen extends StatefulWidget {
  const CustodyRiskScreen({super.key});

  @override
  State<CustodyRiskScreen> createState() => _CustodyRiskScreenState();
}

class _CustodyRiskScreenState extends State<CustodyRiskScreen> {
  int score = 20;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> events = [];
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final snap = await FirebaseFirestore.instance
        .collection('riskEvents')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp')
        .limit(30)
        .get();

    events = snap.docs;
    score = calculateScore(events);

    if (mounted) setState(() {});
  }

  int calculateScore(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var s = 20;

    for (final doc in docs) {
      final data = doc.data();
      final type = data['type'] ?? '';
      final severity = (data['severity'] ?? 1) as int;

      switch (type) {
        case 'missed_exchange':
          s += 15 * severity;
          break;
        case 'late':
          s += 6 * severity;
          break;
        case 'message_conflict':
          s += 4 * severity;
          break;
        case 'compliance':
          s -= 5 * severity;
          break;
      }
    }

    return s.clamp(0, 100).toInt();
  }

  List<FlSpot> buildSpots() {
    var running = 20;

    return events.asMap().entries.map((entry) {
      final data = entry.value.data();
      final type = data['type'];

      switch (type) {
        case 'missed_exchange':
          running += 15;
          break;
        case 'late':
          running += 6;
          break;
        case 'message_conflict':
          running += 4;
          break;
        case 'compliance':
          running -= 5;
          break;
      }

      running = running.clamp(0, 100);

      return FlSpot(entry.key.toDouble(), running.toDouble());
    }).toList();
  }

  List<Map<String, dynamic>> getRecentEvents() {
    return events.reversed.take(5).map((doc) {
      final d = doc.data();
      return {
        'type': d['type'] ?? '',
        'severity': d['severity'] ?? 1,
      };
    }).toList();
  }

  List<String> getRecommendations() {
    final hasMissed =
        events.any((e) => e.data()['type'] == 'missed_exchange');

    final hasLate = events.any((e) => e.data()['type'] == 'late');

    final hasConflict =
        events.any((e) => e.data()['type'] == 'message_conflict');

    final list = <String>[];

    if (hasMissed) {
      list.add('Document missed exchanges immediately');
    }

    if (hasLate) {
      list.add('Arrive early for scheduled exchanges');
    }

    if (hasConflict) {
      list.add('Keep communication brief and factual');
    }

    list.add('Maintain consistent documentation of events');

    return list;
  }

  List<Map<String, dynamic>> buildRiskEventPdfLines() {
    return events.map((doc) {
      final d = doc.data();
      final ts = d['timestamp'];
      var label = '';
      if (ts is Timestamp) {
        label = DateFormat.yMMMMd().add_jm().format(ts.toDate());
      }
      return {
        'type': d['type'] ?? '',
        'severity': d['severity'] ?? 1,
        'timestampLabel': label,
      };
    }).toList();
  }

  String label() {
    if (score < 30) return 'Stable Patterns';
    if (score < 60) return 'Emerging Concerns';
    return 'Elevated Conflict Pattern';
  }

  Color color() {
    if (score < 30) return Colors.greenAccent;
    if (score < 60) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Future<void> generateSummary() async {
    final caseId = context.read<CaseContext>().caseId;
    if (caseId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case context missing')),
      );
      return;
    }

    if (_generating) return;
    setState(() => _generating = true);

    try {
      final pdfBytes = await CourtPdfService.buildCustodyRiskCourtSummaryPdfBytes(
        interactionScore: score,
        scoreLabel: label(),
        riskEventLines: buildRiskEventPdfLines(),
        recommendations: getRecommendations(),
        caseId: caseId,
      );

      await CourtSummaryDocumentsService.saveCourtSummaryPdf(
        pdfBytes: pdfBytes,
        caseId: caseId,
      );

      final previewFile = await CourtPdfService.writePdfBytesToTempFile(
        pdfBytes,
        filename: 'court_summary_preview.pdf',
      );
      await CourtPdfService.rememberLastGeneratedCourtSummaryPath(
        previewFile.path,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Court summary saved')),
      );

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PDFPreviewScreen(
            filePath: previewFile.path,
            title: 'Court Summary',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate summary: $e')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _summarySubtitle(CourtSummaryDocument doc) {
    final d = doc.createdAt ?? DateTime.now();
    return DateFormat.yMMMMd().format(d);
  }

  Widget _recentCourtSummariesSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: PLDesign.card,
        borderRadius: PLDesign.r20,
        boxShadow: PLDesign.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Court Summaries',
            style: PLDesign.sectionTitle,
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<CourtSummaryDocument>>(
            stream: CourtSummaryDocumentsService.watchCourtSummariesForCurrentUser(
              limit: 5,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return Text(
                  'No documents yet. Generate your first court summary.',
                  style: PLDesign.caption.copyWith(height: 1.35),
                );
              }
              return Column(
                children: list.map((doc) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: PLDesign.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => PDFPreviewScreen(
                                downloadUrl: doc.fileUrl,
                                title: 'Court Summary',
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.picture_as_pdf_rounded,
                                color: PLDesign.primary.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Court Summary',
                                      style: PLDesign.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _summarySubtitle(doc),
                                      style: PLDesign.caption,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: PLDesign.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _insightsPremiumGate({required bool locked, required Widget child}) {
    if (!locked) return child;
    return PremiumLockedTapHost(
      locked: true,
      onLockedTap: () => showPremiumUpgradeSheet(
        context,
        feature: DashboardPremiumFeature.insightsCluster,
      ),
      child: PremiumTeaserShell(
        locked: true,
        borderRadius: 20,
        child: IgnorePointer(
          ignoring: true,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final locked =
        !session.isAttorney && !session.unlockedParentPremiumFeatures;

    final spots = buildSpots();
    final eventsList = getRecentEvents();
    final actions = getRecommendations();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(title: const Text('Custody Risk')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: PLDesign.card,
              borderRadius: PLDesign.r20,
              boxShadow: PLDesign.softShadow,
            ),
            child: Column(
              children: [
                Container(
                  height: 10,
                  width: 10,
                  decoration: BoxDecoration(
                    color: color(),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Interaction Score', style: PLDesign.caption),
                const SizedBox(height: 10),
                Text(
                  score.toString(),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label(), style: PLDesign.caption),
                const SizedBox(height: 10),
                Text(
                  'Based on recorded events. Not a legal determination.',
                  style: PLDesign.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _insightsPremiumGate(
            locked: locked,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PLDesign.card,
                    borderRadius: PLDesign.r20,
                    boxShadow: [
                      BoxShadow(
                        color: PLDesign.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots.isEmpty ? [const FlSpot(0, 20)] : spots,
                          isCurved: true,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _recentCourtSummariesSection(),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: PLDesign.card,
                    borderRadius: PLDesign.r20,
                    boxShadow: PLDesign.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Recorded Events',
                        style: PLDesign.sectionTitle,
                      ),
                      const SizedBox(height: 12),
                      if (eventsList.isEmpty)
                        const Text('No recent events', style: PLDesign.caption)
                      else
                        ...eventsList.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${e['type']} (Severity ${e['severity']})',
                              style: PLDesign.body,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: PLDesign.card,
                    borderRadius: PLDesign.r20,
                    boxShadow: PLDesign.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suggested Documentation Practices',
                        style: PLDesign.sectionTitle,
                      ),
                      const SizedBox(height: 12),
                      ...actions.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('• $a', style: PLDesign.body),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: locked
                ? () => showPremiumUpgradeSheet(
                      context,
                      feature: DashboardPremiumFeature.insightsCluster,
                    )
                : (_generating ? null : generateSummary),
            child: _generating
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Generate Court Summary'),
          ),
        ],
      ),
    );
  }
}
