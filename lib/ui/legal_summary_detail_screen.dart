import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';

/// Export-ready view of a stored court communication summary.
class LegalSummaryDetailScreen extends StatelessWidget {
  const LegalSummaryDetailScreen({
    super.key,
    required this.caseId,
    required this.summaryId,
  });

  final String caseId;
  final String summaryId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('cases')
        .doc(caseId)
        .collection('legalSummaries')
        .doc(summaryId);

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('courtCommunicationSummary')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Copy full text',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              final snap = await ref.get();
              final text = (snap.data()?['summaryText'] ?? '').toString();
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tTone('summaryCopiedToClipboard'))),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load summary: ${snap.error}',
                  style: PLDesign.body.copyWith(color: PLDesign.danger),
                ),
              ),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() ?? {};
          final text = (data['summaryText'] ?? '').toString();
          final created = data['createdAt'];
          DateTime? at;
          if (created is Timestamp) at = created.toDate();
          final df = DateFormat('MMM d, yyyy · HH:mm');
          final entryDateFmt = DateFormat('MMMM d, yyyy');
          final meta = data['structured'];
          final messageCount = data['messageCount'];
          final kind = (data['summaryKind'] ?? '').toString();
          final isAttorneyBrief = kind == 'attorney_brief';
          final generatedAt = at ?? DateTime.now();

          final actions = meta is Map && meta['actions'] is List
              ? List<Map<String, dynamic>>.from(
                  (meta['actions'] as List).map(
                    (e) => Map<String, dynamic>.from(
                      e is Map ? Map<dynamic, dynamic>.from(e) : <String, dynamic>{},
                    ),
                  ),
                )
              : <Map<String, dynamic>>[];

          Map<String, dynamic>? courtInsights;
          String? aiInsightParagraph;
          if (meta is Map) {
            final raw = meta['courtInsights'];
            if (raw is Map) {
              courtInsights = Map<String, dynamic>.from(
                raw.map((k, v) => MapEntry(k.toString(), v)),
              );
            }
            final ai = meta['aiInsightParagraph'];
            if (ai != null) aiInsightParagraph = ai.toString();
          }

          return Container(
            decoration: const BoxDecoration(gradient: PLDesign.pageGradient),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: PLDesign.elevatedCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAttorneyBrief
                              ? 'Attorney brief (messages + timeline + flags)'
                              : 'Neutral record',
                          style: PLDesign.caption.copyWith(
                            color: PLDesign.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (at != null)
                          Text(
                            'Generated ${df.format(at)}',
                            style: PLDesign.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (messageCount != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Messages reviewed: $messageCount',
                              style: PLDesign.caption,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (courtInsights != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _LegalSummaryInsightsCard(
                        insights: courtInsights,
                        aiParagraph: aiInsightParagraph,
                      ),
                    ),
                  if (actions.isNotEmpty)
                    ...actions.map((entry) {
                      final dateText = (entry['date'] ?? '').toString().trim();
                      final senderId = (entry['senderId'] ?? '').toString().trim();
                      final message =
                          (entry['message'] ?? entry['excerpt'] ?? '').toString();
                      DateTime? parsedDate;
                      if (dateText.isNotEmpty) {
                        parsedDate = DateTime.tryParse(dateText);
                      }
                      final displayDate = parsedDate != null
                          ? entryDateFmt.format(parsedDate.toLocal())
                          : (dateText.isEmpty ? 'Date pending' : dateText);
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: PLDesign.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PLDesign.border),
                          boxShadow: PLDesign.softShadow,
                        ),
                        child: SelectableText(
                          '$displayDate\n'
                          'Sender ID: ${senderId.isEmpty ? 'unknown' : senderId}\n\n'
                          'Message:\n'
                          '"$message"',
                          style: PLDesign.body.copyWith(
                            height: 1.55,
                            fontSize: 14,
                          ),
                        ),
                      );
                    })
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: PLDesign.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PLDesign.border),
                        boxShadow: PLDesign.softShadow,
                      ),
                      child: SelectableText(
                        text.isEmpty
                            ? 'No summary text was stored for this document.'
                            : text,
                        style: PLDesign.body.copyWith(
                          height: 1.55,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Divider(color: PLDesign.border.withValues(alpha: 0.8)),
                  const SizedBox(height: 10),
                  SelectableText(
                    'Generated by ParentLedger\n'
                    'Case ID: $caseId\n'
                    'Report generated: ${df.format(generatedAt)}\n\n'
                    'This document is a neutral, system-generated summary of recorded communications.\n'
                    'No interpretation or modification has been applied.',
                    style: PLDesign.caption.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Metrics, lexical screening tallies, narrative, weekly trend chart, optional AI overview.
class _LegalSummaryInsightsCard extends StatelessWidget {
  const _LegalSummaryInsightsCard({
    required this.insights,
    this.aiParagraph,
  });

  final Map<String, dynamic> insights;
  final String? aiParagraph;

  static double _num(dynamic v) => v is num ? v.toDouble() : 0;

  @override
  Widget build(BuildContext context) {
    final metrics = insights['metrics'];
    final analysis = insights['messageAnalysis'];
    final narrative = (insights['narrativeParagraph'] ?? '').toString().trim();
    final trendRaw = insights['weeklyTrend'];
    List<Map<String, dynamic>> weekly = [];
    if (trendRaw is List) {
      for (final e in trendRaw) {
        if (e is Map) {
          weekly.add(Map<String, dynamic>.from(
            e.map((k, v) => MapEntry(k.toString(), v)),
          ));
        }
      }
    }

    Map<String, dynamic>? metMap;
    if (metrics is Map) {
      metMap = Map<String, dynamic>.from(
        metrics.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    Map<String, dynamic>? anaMap;
    if (analysis is Map) {
      anaMap = Map<String, dynamic>.from(
        analysis.map((k, v) => MapEntry(k.toString(), v)),
      );
    }

    final latePct = metMap != null ? _num(metMap['lateArrivalPercent']).round() : 0;
    final missed = metMap != null ? _num(metMap['missedExchanges']).round() : 0;
    final avgH = metMap?['avgResponseHours'];

    final prof = anaMap != null ? _num(anaMap['profanitySignals']).round() : 0;
    final agg = anaMap != null ? _num(anaMap['aggressiveToneSignals']).round() : 0;
    final thr = anaMap != null ? _num(anaMap['threatLanguageSignals']).round() : 0;

    final shortFmt = DateFormat('M/d');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PLDesign.border),
        boxShadow: PLDesign.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: PLDesign.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Court-ready insights',
                style: PLDesign.sectionTitle.copyWith(fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Derived from exchanges, check-ins, timeline, and screened messages.',
            style: PLDesign.caption.copyWith(color: PLDesign.textMuted, height: 1.35),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  label: 'Late arrivals',
                  value: '$latePct%',
                  hint: 'of check-ins',
                  color: PLDesign.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  label: 'Missed exch.',
                  value: '$missed',
                  hint: 'scheduled past due',
                  color: PLDesign.danger,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricBox(
                  label: 'Avg response',
                  value: avgH == null ? '—' : '${avgH}h',
                  hint: 'cross-party',
                  color: PLDesign.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Message screening (lexical)',
            style: PLDesign.caption.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Profanity', prof, PLDesign.danger),
              _chip('Aggressive tone', agg, PLDesign.warning),
              _chip('Threat language', thr, PLDesign.danger),
            ],
          ),
          if (anaMap?['methodNote'] != null) ...[
            const SizedBox(height: 10),
            Text(
              anaMap!['methodNote'].toString(),
              style: PLDesign.caption.copyWith(
                color: PLDesign.textMuted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          if (narrative.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Summary narrative',
              style: PLDesign.caption.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              narrative,
              style: PLDesign.body.copyWith(height: 1.45, fontSize: 14),
            ),
          ],
          if (aiParagraph != null && aiParagraph!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PLDesign.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: PLDesign.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI-assisted record overview',
                    style: PLDesign.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: PLDesign.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    aiParagraph!.trim(),
                    style: PLDesign.body.copyWith(height: 1.45, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
          if (weekly.length >= 2) ...[
            const SizedBox(height: 20),
            Text(
              'Weekly behavior trend (8 weeks)',
              style: PLDesign.caption.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Solid: exchange + timeline flags. Dashed: message conduct signals.',
              style: PLDesign.caption.copyWith(
                color: PLDesign.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: _WeeklyTrendChart(
                weekly: weekly,
                shortFmt: shortFmt,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricBox({
    required String label,
    required String value,
    required String hint,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PLDesign.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PLDesign.border.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PLDesign.caption.copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          Text(
            value,
            style: PLDesign.statNumber.copyWith(
              fontSize: 20,
              color: color,
            ),
          ),
          Text(
            hint,
            style: PLDesign.caption.copyWith(fontSize: 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int count, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $count',
        style: PLDesign.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    );
  }
}

class _WeeklyTrendChart extends StatelessWidget {
  const _WeeklyTrendChart({
    required this.weekly,
    required this.shortFmt,
  });

  final List<Map<String, dynamic>> weekly;
  final DateFormat shortFmt;

  static double _n(dynamic v) => v is num ? v.toDouble() : 0;

  @override
  Widget build(BuildContext context) {
    final spotsRecord = <FlSpot>[];
    final spotsMessage = <FlSpot>[];
    var maxY = 4.0;
    for (var i = 0; i < weekly.length; i++) {
      final w = weekly[i];
      final ex = _n(w['exchangeIssues']);
      final tl = _n(w['timelineViolations']);
      final msg = _n(w['messageConductFlags']);
      final rec = ex + tl;
      maxY = math.max(maxY, math.max(rec, msg) * 1.15 + 0.5);
      spotsRecord.add(FlSpot(i.toDouble(), rec));
      spotsMessage.add(FlSpot(i.toDouble(), msg));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max(1, maxY / 4),
          getDrawingHorizontalLine: (v) => FlLine(
            color: PLDesign.border.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: math.max(1, maxY / 4),
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: PLDesign.caption.copyWith(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= weekly.length) return const SizedBox.shrink();
                final ws = weekly[i]['weekStart']?.toString();
                DateTime? d;
                if (ws != null) d = DateTime.tryParse(ws);
                final lab = d != null ? shortFmt.format(d) : '$i';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    lab,
                    style: PLDesign.caption.copyWith(fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spotsRecord,
            isCurved: true,
            color: PLDesign.warning,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: spotsMessage,
            isCurved: true,
            color: PLDesign.primary,
            barWidth: 2,
            dashArray: [6, 4],
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}
