import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../design/design.dart';
import '../models/case_event.dart';
import '../models/timeline_event_model.dart';
import '../providers/case_context.dart';
import '../services/case_event_service.dart';
import '../services/export_service.dart';
import '../services/timeline_actor_resolver.dart';
import '../services/timeline_integrity_service.dart';
import '../services/timeline_pdf_service.dart';
import '../timeline/case_event_formatter.dart';
import '../timeline/timeline_mapper.dart';
import '../timeline/timeline_presentation.dart';
import '../util/subscription_limits.dart';
import '../util/subscription_gate.dart';
import 'widgets/attorney_case_switcher.dart';
import 'package:provider/provider.dart';

/// Court-oriented unified timeline: grouped by day, actors resolved, no raw UIDs.
class CaseUnifiedTimelineScreen extends StatefulWidget {
  const CaseUnifiedTimelineScreen({
    super.key,
    required this.caseId,
    /// When set, only events whose local timestamp falls on this calendar day.
    this.filterToDay,
  });

  final String caseId;
  final DateTime? filterToDay;

  @override
  State<CaseUnifiedTimelineScreen> createState() =>
      _CaseUnifiedTimelineScreenState();
}

class _CaseUnifiedTimelineScreenState extends State<CaseUnifiedTimelineScreen> {
  bool _selectMode = false;
  final Set<String> _selectedIds = <String>{};

  /// One timeline pipeline per screen — [build] calls must not allocate new streams (scroll).
  late final Stream<List<TimelineEventModel>> _timelineModelsStream;

  @override
  void initState() {
    super.initState();
    _timelineModelsStream =
        CaseEventService.watchTimelineModels(widget.caseId);
  }

  static IconData _iconForCategory(TimelineDisplayCategory c) {
    switch (c) {
      case TimelineDisplayCategory.message:
        return Icons.chat_bubble_outline_rounded;
      case TimelineDisplayCategory.exchange:
        return Icons.swap_horiz_rounded;
      case TimelineDisplayCategory.expense:
        return Icons.receipt_long_rounded;
      case TimelineDisplayCategory.violation:
        return Icons.gavel_rounded;
    }
  }

  Future<void> _exportFullTimelinePdf() async {
    final session = context.read<CaseContext>();
    final allowExport = session.isPremium || session.isAttorney;
    if (!await requirePremiumOrPrompt(context, guard: allowExport)) return;
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
    try {
      final v = await TimelineIntegrityService.verifyEventChain(widget.caseId);
      if (!v.isValid) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              v.message ?? 'Timeline integrity check failed. Export blocked.',
            ),
          ),
        );
        return;
      }
      var events = await CaseEventService.fetchTimelineModels(widget.caseId);
      if (widget.filterToDay != null) {
        final d = widget.filterToDay!;
        final start = DateTime(d.year, d.month, d.day);
        final end = start.add(const Duration(days: 1));
        events = events.where((e) {
          final t = e.createdAt.toLocal();
          return !t.isBefore(start) && t.isBefore(end);
        }).toList();
      }
      final uids = events.map((e) => e.actorId).where((s) => s.isNotEmpty).toSet();
      final actors = await TimelineActor.loadMany(uids);
      final pdf = await TimelinePdfService.buildPdfBytes(
        caseId: widget.caseId,
        caseTitle: 'Case ${widget.caseId}',
        eventsNewestFirst: events,
        actors: actors,
        integrityVerified: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await Printing.sharePdf(
        bytes: pdf,
        filename: 'timeline_${widget.caseId}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayHeaderFmt = DateFormat('MMM d, yyyy');

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(
          widget.filterToDay != null
              ? '${context.tTone('caseTimeline')} · ${DateFormat.yMMMd().format(widget.filterToDay!)}'
              : context.tTone('caseTimeline'),
        ),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
        actions: [
          const AttorneyCaseSwitcher(),
          if (!_selectMode)
            IconButton(
              tooltip: 'Export PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _exportFullTimelinePdf,
            ),
          if (_selectMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selectMode = false;
                _selectedIds.clear();
              }),
            )
          else
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() {
                _selectMode = true;
                _selectedIds.clear();
              }),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (context.watch<CaseContext>().isAttorney)
            _AttorneyInsightsPanel(caseId: widget.caseId),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              'Time-stamped and immutable record',
              style: PLDesign.caption.copyWith(
                color: PLDesign.textMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TimelineEventModel>>(
              stream: _timelineModelsStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load timeline: ${snap.error}',
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
                var events = snap.data ?? [];
                if (widget.filterToDay != null) {
                  final d = widget.filterToDay!;
                  final start = DateTime(d.year, d.month, d.day);
                  final end = start.add(const Duration(days: 1));
                  events = events.where((e) {
                    final t = e.createdAt.toLocal();
                    return !t.isBefore(start) && t.isBefore(end);
                  }).toList();
                }
                final cx = context.watch<CaseContext>();
                final eventsBeforeMessageCap = List<TimelineEventModel>.from(
                  events,
                );
                events = cx.isAttorney
                    ? events
                    : applyFreeTierTimelineFilter(events, context);
                final showLimitedMessageBanner = !cx.isAttorney &&
                    !cx.isPremium &&
                    eventsBeforeMessageCap.where((e) => e.isMessageLike).length >
                        events.where((e) => e.isMessageLike).length;
                if (events.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timeline,
                              size: 48, color: PLDesign.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            widget.filterToDay != null
                                ? 'No events on this day'
                                : 'No activity recorded yet',
                            style: PLDesign.sectionTitle.copyWith(fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.filterToDay != null
                                ? 'Try another date from the calendar or view the full timeline.'
                                : 'Case timeline entries appear here in chronological order.',
                            style: PLDesign.caption.copyWith(height: 1.35),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final uids = <String>{};
                for (final ev in events) {
                  if (ev.actorId.isNotEmpty) uids.add(ev.actorId);
                }

                return FutureBuilder<Map<String, TimelineActor>>(
                  future: TimelineActor.loadMany(uids),
                  builder: (context, actorSnap) {
                    if (actorSnap.connectionState == ConnectionState.waiting &&
                        !actorSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final actors = actorSnap.data ?? {};

                    final grouped = TimelinePresentation.groupByDay(events);
                    final days = grouped.keys.toList()
                      ..sort((a, b) => b.compareTo(a));

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      itemCount: days.length +
                          (showLimitedMessageBanner ? 1 : 0),
                      itemBuilder: (context, di) {
                        if (showLimitedMessageBanner && di == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: PLDesign.card,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: PLDesign.info,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Free plan: showing ${SubscriptionLimits.freeMaxTimelineMessageEvents} most recent message records. Upgrade for your complete timeline.',
                                        style: PLDesign.caption.copyWith(
                                          height: 1.35,
                                          color: PLDesign.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        final diAdjusted =
                            showLimitedMessageBanner ? di - 1 : di;
                        final day = days[diAdjusted];
                        final dayDocs = grouped[day]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 8, bottom: 12, left: 2),
                              child: Text(
                                dayHeaderFmt.format(day),
                                style: PLDesign.sectionTitle.copyWith(
                                  fontSize: 17,
                                  color: PLDesign.textPrimary,
                                ),
                              ),
                            ),
                            ...dayDocs.asMap().entries.map((entry) {
                              final i = entry.key;
                              final ev = entry.value;
                              final rawType = TimelinePresentation.timelineUiType(ev);
                              final uid = ev.actorId;
                              final metaMap = TimelinePresentation.metaMapFor(ev);

                              final when = ev.createdAt;

                              final category =
                                  TimelinePresentation.categoryForRawType(rawType);
                              final msgClass = TimelinePresentation.classifyMessage(
                                rawType: rawType,
                                meta: metaMap,
                              );
                              final severity = TimelinePresentation.severityForEvent(
                                rawType: rawType,
                                category: category,
                                msgClass: msgClass,
                                meta: metaMap,
                              );

                              final actor = actors[uid];
                              final actorLine = TimelinePresentation.actorLine(
                                e: ev,
                                resolvedDisplayName: actor?.fullName,
                                resolvedRoleLabel: actor?.roleLabel,
                              );
                              final fromLine = 'From: $actorLine';

                              final formal =
                                  CaseEventFormatter.format(ev, rawType);
                              final recordBody =
                                  CaseEventFormatter.recordBody(ev, rawType);
                              final isMessageLike = rawType == 'message_sent' ||
                                  rawType == 'summary_generated';
                              final displayBody = recordBody.isNotEmpty
                                  ? recordBody
                                  : (isMessageLike ? '—' : '');
                              final showBodyBlock = displayBody.isNotEmpty;

                              final headline = formal.title;
                              final formalSubtitle = formal.subtitle;
                              final timeLabel = DateFormat.yMMMd()
                                  .add_jm()
                                  .format(when.toLocal());

                              final flagText = TimelinePresentation.flagLine(metaMap);

                              final isSelected = _selectedIds.contains(ev.id);
                              final card = _TimelineEventCard(
                                timeText: timeLabel,
                                category: category,
                                categoryLabel:
                                    TimelinePresentation.labelForCategory(category),
                                categoryIcon: _iconForCategory(category),
                                severity: severity,
                                headline: headline,
                                formalSubtitle: formalSubtitle,
                                fromLine: fromLine,
                                body: displayBody,
                                showBodyBlock: showBodyBlock,
                                classification: msgClass,
                                contentLabel: rawType == 'summary_generated'
                                    ? 'Summary'
                                    : (isMessageLike && displayBody.isNotEmpty
                                        ? 'Recorded text'
                                        : null),
                                wrapBodyInQuotes: isMessageLike &&
                                    recordBody.isNotEmpty &&
                                    !recordBody.contains('\n'),
                                flagLine: flagText.isNotEmpty ? flagText : null,
                                selected: isSelected,
                                selectMode: _selectMode,
                              );

                              final isLast = i == dayDocs.length - 1;
                              final isLastDay =
                                  diAdjusted == days.length - 1;

                              return GestureDetector(
                                onTap: _selectMode
                                    ? () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedIds.remove(ev.id);
                                          } else {
                                            _selectedIds.add(ev.id);
                                          }
                                        });
                                      }
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      card,
                                      if (!isLast || !isLastDay)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: PLDesign.border
                                                .withValues(alpha: 0.75),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () async {
                                for (final id in _selectedIds) {
                                  await CaseEventService.mergeAnnotationTag(
                                    caseId: widget.caseId,
                                    eventId: id,
                                    tag: 'evidence',
                                  );
                                }
                              },
                        child: const Text('Mark as Evidence'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () async {
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                final session = context.read<CaseContext>();
                                final allowExport =
                                    session.isPremium || session.isAttorney;
                                if (!await requirePremiumOrPrompt(
                                  context,
                                  guard: allowExport,
                                )) {
                                  return;
                                }
                                final v = await TimelineIntegrityService
                                    .verifyEventChain(widget.caseId);
                                if (!v.isValid) {
                                  if (!context.mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        v.message ??
                                            'Timeline integrity check failed.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final ids = _selectedIds.take(10).toList();
                                final snap = await FirebaseFirestore.instance
                                    .collection('case_events')
                                    .where(FieldPath.documentId, whereIn: ids)
                                    .get();
                                if (!context.mounted) return;
                                final models = snap.docs
                                    .map(TimelineMapper.mapFromFirestore)
                                    .toList()
                                  ..sort((a, b) =>
                                      b.createdAt.compareTo(a.createdAt));
                                final uids = models
                                    .map((e) => e.actorId)
                                    .where((u) => u.isNotEmpty)
                                    .toSet();
                                final actors =
                                    await TimelineActor.loadMany(uids);
                                final pdf =
                                    await TimelinePdfService.buildPdfBytes(
                                  caseId: widget.caseId,
                                  caseTitle:
                                      'Case ${widget.caseId} (selection)',
                                  eventsNewestFirst: models,
                                  actors: actors,
                                  integrityVerified: true,
                                );
                                await Printing.sharePdf(
                                  bytes: pdf,
                                  filename:
                                      'timeline_selection_${widget.caseId}.pdf',
                                );
                                if (!context.mounted) return;
                                final rows = models.map((ev) {
                                  final raw =
                                      TimelinePresentation.timelineUiType(ev);
                                  final metaMap =
                                      TimelinePresentation.metaMapFor(ev);
                                  final formal =
                                      CaseEventFormatter.format(ev, raw);
                                  final rb =
                                      CaseEventFormatter.recordBody(ev, raw);
                                  final desc = [
                                    formal.title,
                                    formal.subtitle,
                                    if (rb.isNotEmpty) rb,
                                  ].join(' ');
                                  return ExportRow(
                                    type: raw,
                                    date: ev.createdAt,
                                    description: desc,
                                    amount: (metaMap['amount'] is num)
                                        ? (metaMap['amount'] as num).toDouble()
                                        : null,
                                    tags: List<String>.from(
                                        metaMap['tags'] ?? const []),
                                    evidence: List<String>.from(
                                            metaMap['tags'] ?? const [])
                                        .contains('evidence'),
                                  );
                                }).toList();
                                final csv = ExportService.buildCsv(rows);
                                await Clipboard.setData(
                                  ClipboardData(
                                      text: String.fromCharCodes(csv)),
                                );
                                if (!context.mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Timeline PDF shared and CSV copied.',
                                    ),
                                  ),
                                );
                              },
                        child: const Text('Export'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _AttorneyInsightsPanel extends StatelessWidget {
  const _AttorneyInsightsPanel({required this.caseId});

  final String caseId;

  static Future<int> _violationsLast30(String caseId) async {
    final events = await CaseEventService.fetchCaseEvents(caseId);
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return events.where((e) {
      if (!e.createdAt.isAfter(cutoff)) return false;
      final flag = e.metadata['legalFlag']?.toString();
      if (flag != null && flag.isNotEmpty) return true;
      if (e.type == CaseEventTypes.statusChange &&
          e.title.toLowerCase().contains('flag')) {
        return true;
      }
      return false;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance.collection('cases').doc(caseId);
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _violationsLast30(caseId),
        db
            .collection('expenses')
            .where('status', isEqualTo: 'unpaid')
            .get(),
        db.collection('insights').doc('risk').get(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }
        final violations = snap.data![0] as int;
        final unpaid = (snap.data![1] as QuerySnapshot<Map<String, dynamic>>)
            .docs
            .fold<double>(
              0,
              (total, d) =>
                  total +
                  ((d.data()['amount'] is num)
                      ? (d.data()['amount'] as num).toDouble()
                      : 0),
            );
        final riskDoc =
            (snap.data![2] as DocumentSnapshot<Map<String, dynamic>>).data() ??
                {};
        final score = (riskDoc['score'] is num)
            ? (riskDoc['score'] as num).toDouble()
            : 80;
        final sentiment = (riskDoc['sentiment'] ?? 'neutral').toString();
        final color = score >= 80
            ? Colors.green
            : (score >= 60 ? Colors.orange : Colors.red);
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PLDesign.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attorney Insights',
                  style: PLDesign.sectionTitle.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              Text('Compliance score: ${score.toStringAsFixed(0)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              Text('Violations (30d): $violations'),
              Text('Unpaid expenses total: \$${unpaid.toStringAsFixed(2)}'),
              Text('Communication sentiment: $sentiment'),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineEventCard extends StatelessWidget {
  const _TimelineEventCard({
    required this.timeText,
    required this.category,
    required this.categoryLabel,
    required this.categoryIcon,
    required this.severity,
    required this.headline,
    required this.formalSubtitle,
    required this.fromLine,
    required this.body,
    this.showBodyBlock = true,
    this.classification,
    this.contentLabel,
    this.wrapBodyInQuotes = false,
    this.flagLine,
    this.selected = false,
    this.selectMode = false,
  });

  final String timeText;
  final TimelineDisplayCategory category;
  final String categoryLabel;
  final IconData categoryIcon;
  final TimelineSeverity severity;
  /// Neutral court-style title ([CaseEventFormatter.format].title).
  final String headline;
  /// Neutral factual line ([CaseEventFormatter.format].subtitle).
  final String formalSubtitle;
  final String fromLine;
  final String body;
  final bool showBodyBlock;
  final MessageClassification? classification;

  /// e.g. "Recorded text" / "Summary"; null = no prefixed label.
  final String? contentLabel;
  final bool wrapBodyInQuotes;
  final String? flagLine;
  final bool selected;
  final bool selectMode;

  @override
  Widget build(BuildContext context) {
    Color bg = PLDesign.card;
    Color border = PLDesign.border.withValues(alpha: 0.85);
    switch (severity) {
      case TimelineSeverity.subtle:
        break;
      case TimelineSeverity.warning:
        bg = PLDesign.warning.withValues(alpha: 0.1);
        border = PLDesign.warning.withValues(alpha: 0.45);
        break;
      case TimelineSeverity.risk:
        bg = PLDesign.danger.withValues(alpha: 0.1);
        border = PLDesign.danger.withValues(alpha: 0.42);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? PLDesign.primary : border,
          width: selected ? 1.8 : (severity == TimelineSeverity.subtle ? 1 : 1.4),
        ),
        boxShadow: PLDesign.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryIcon, size: 18, color: PLDesign.primary),
              const SizedBox(width: 8),
              Text(
                categoryLabel,
                style: PLDesign.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: PLDesign.textPrimary,
                ),
              ),
              if (classification != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: PLDesign.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: PLDesign.border.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Text(
                    'AI: ${classification!.label}',
                    style: PLDesign.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: PLDesign.sectionTitle.copyWith(fontSize: 16, height: 1.25),
          ),
          if (formalSubtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              formalSubtitle,
              style: PLDesign.caption.copyWith(
                color: PLDesign.textMuted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            timeText,
            style: PLDesign.caption.copyWith(
              color: PLDesign.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            fromLine,
            style: PLDesign.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (showBodyBlock) ...[
            const SizedBox(height: 10),
            if (contentLabel != null) ...[
              Text(
                '$contentLabel:',
                style: PLDesign.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: PLDesign.textMuted,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              wrapBodyInQuotes ? '"$body"' : body,
              style: PLDesign.body.copyWith(
                height: 1.4,
                fontSize: 14,
              ),
            ),
          ],
          if (flagLine != null && flagLine!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Flag: $flagLine',
              style: PLDesign.caption.copyWith(
                color: severity == TimelineSeverity.risk
                    ? PLDesign.danger
                    : PLDesign.warning,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
          if (selectMode) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? PLDesign.primary : PLDesign.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
