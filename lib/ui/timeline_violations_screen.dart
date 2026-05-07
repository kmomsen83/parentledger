import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../util/subscription_gate.dart';
import '../models/case_event.dart';
import '../services/case_event_service.dart';
import '../services/case_timeline_service.dart';
import '../services/export_service.dart';
import '../services/timeline_violation_filter.dart';
import 'widgets/attorney_case_switcher.dart';
import 'widgets/empty_state_panel.dart';
import 'widgets/trust_elements.dart';

/// Recorded timeline violations only (not AI compliance scan).
/// Accent: blue — distinct from [CaseInsightsScreen] (purple).
class TimelineViolationsScreen extends StatefulWidget {
  const TimelineViolationsScreen({super.key, required this.caseId});

  final String caseId;

  static const Color accent = Color(0xFF3B82F6);

  @override
  State<TimelineViolationsScreen> createState() =>
      _TimelineViolationsScreenState();
}

class _TimelineViolationsScreenState extends State<TimelineViolationsScreen> {
  bool _selectMode = false;
  final Set<String> _selected = <String>{};

  Future<void> _bulkTag(String tag) async {
    for (final id in _selected) {
      await CaseEventService.mergeAnnotationTag(
        caseId: widget.caseId,
        eventId: id,
        tag: tag,
      );
    }
  }

  Future<void> _markEvidence() async {
    for (final id in _selected) {
      await CaseTimelineService.setEvidenceFlag(
        caseId: widget.caseId,
        eventId: id,
        isEvidence: true,
      );
    }
  }

  Future<void> _exportSelected(List<CaseEvent> selected) async {
    final rows = selected.map((e) {
      final uiType = TimelineViolationFilter.syntheticViolationUiType(e);
      final meta = e.metadata;
      return ExportRow(
        type: uiType.isNotEmpty ? uiType : 'violation',
        date: e.createdAt,
        description:
            TimelineViolationFilter.previewLine(uiType.isNotEmpty ? uiType : 'violation_flagged', meta),
        tags: List<String>.from(meta['tags'] ?? const []),
        evidence: meta['isEvidence'] == true ||
            List<String>.from(meta['tags'] ?? const []).contains('evidence'),
      );
    }).toList();
    final pdfBytes = await ExportService.buildPdf(
      caseTitle: 'Case ${widget.caseId}',
      childrenCount: 0,
      rows: rows,
    );
    await Printing.sharePdf(
        bytes: pdfBytes, filename: 'violations_${widget.caseId}.pdf');
    final csvBytes = ExportService.buildCsv(rows);
    await Clipboard.setData(
        ClipboardData(text: String.fromCharCodes(csvBytes)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF shared and CSV copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        iconTheme: const IconThemeData(color: TimelineViolationsScreen.accent),
        title: Text(
          _selectMode ? '${_selected.length} selected' : 'Items to review',
          style: PLDesign.sectionTitle.copyWith(
            color: PLDesign.textPrimary,
            fontSize: 18,
          ),
        ),
        actions: [
          const AttorneyCaseSwitcher(),
          if (_selectMode) ...[
            TextButton(
              onPressed: () => setState(() => _selected.clear()),
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () async {
                await _markEvidence();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Marked as evidence'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                setState(() {
                  _selectMode = false;
                  _selected.clear();
                });
              },
              child: const Text('Mark as Evidence'),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() {
                _selectMode = true;
                _selected.clear();
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TrustNote(
              text:
                  'These items are based on recorded activity and may help with case review.',
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CaseEvent>>(
              stream: CaseEventService.watchCaseEvents(widget.caseId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: EmptyStatePanel(
                        icon: Icons.cloud_off_outlined,
                        title: 'Couldn’t load violations',
                        message:
                            'Check your connection and try again. Open the case timeline from Case Center if this continues.',
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final events = snap.data ?? [];
                final violations =
                    events.where(TimelineViolationFilter.caseEventIsViolation).toList();
                if (violations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.gavel_rounded,
                              size: 56,
                              color: TimelineViolationsScreen.accent
                                  .withValues(alpha: 0.45)),
                          const SizedBox(height: 20),
                          Text(
                            'No violations recorded',
                            style: PLDesign.sectionTitle.copyWith(fontSize: 20),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Flags, missed exchanges, and unpaid expenses appear here once they are logged on your case timeline.',
                            style: PLDesign.caption.copyWith(
                              color: PLDesign.textMuted,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  itemCount: violations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final ev = violations[i];
                    final type =
                        TimelineViolationFilter.syntheticViolationUiType(ev);
                    final meta = ev.metadata;
                    final when = ev.createdAt;

                    final dateStr =
                        DateFormat.yMMMd().add_jm().format(when.toLocal());

                    final selected = _selected.contains(ev.id);
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (_selectMode) {
                            setState(() {
                              if (selected) {
                                _selected.remove(ev.id);
                              } else {
                                _selected.add(ev.id);
                              }
                            });
                            return;
                          }
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => TimelineViolationDetailScreen(
                                eventId: ev.id,
                                type: type,
                                occurredAt: when,
                                metadata: meta,
                              ),
                            ),
                          );
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            color: PLDesign.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? TimelineViolationsScreen.accent
                                  : TimelineViolationsScreen.accent
                                      .withValues(alpha: 0.35),
                              width: selected ? 1.7 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.circle_notifications,
                                  color: TimelineViolationsScreen.accent,
                                  size: 26),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      TimelineViolationFilter.displayTypeLabel(
                                          type),
                                      style: PLDesign.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateStr,
                                      style: PLDesign.caption.copyWith(
                                        color: PLDesign.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      TimelineViolationFilter.previewLine(
                                          type, meta),
                                      style: PLDesign.caption
                                          .copyWith(height: 1.35),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              _selectMode
                                  ? Checkbox(
                                      value: selected,
                                      onChanged: (_) {
                                        setState(() {
                                          if (selected) {
                                            _selected.remove(ev.id);
                                          } else {
                                            _selected.add(ev.id);
                                          }
                                        });
                                      },
                                    )
                                  : Icon(Icons.chevron_right,
                                      color: TimelineViolationsScreen.accent
                                          .withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                      ),
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
                        onPressed: _selected.isEmpty
                            ? null
                            : () async {
                                await _bulkTag('court_review');
                              },
                        child: const Text('Tag'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _selected.isEmpty
                            ? null
                            : () async {
                                final session = context.read<CaseContext>();
                                final allowExport = session.isPremium ||
                                    session.isAttorney;
                                if (!await requirePremiumOrPrompt(
                                  context,
                                  guard: allowExport,
                                )) {
                                  return;
                                }
                                final ids = _selected.toList();
                                final snap = await FirebaseFirestore.instance
                                    .collection('case_events')
                                    .where(FieldPath.documentId, whereIn: ids)
                                    .get();
                                final events = snap.docs.map(CaseEvent.fromDoc).toList();
                                await _exportSelected(events);
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

class TimelineViolationDetailScreen extends StatelessWidget {
  const TimelineViolationDetailScreen({
    super.key,
    required this.eventId,
    required this.type,
    required this.metadata,
    this.occurredAt,
  });

  final String eventId;
  final String type;
  final Map<String, dynamic> metadata;
  final DateTime? occurredAt;

  static const Color accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final dateStr = occurredAt != null
        ? DateFormat.yMMMd().add_jm().format(occurredAt!.toLocal())
        : 'Timestamp pending';

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        iconTheme: const IconThemeData(color: accent),
        title: Text(
          'Violation detail',
          style: PLDesign.sectionTitle.copyWith(fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            TimelineViolationFilter.displayTypeLabel(type),
            style: PLDesign.sectionTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(dateStr,
              style: PLDesign.caption.copyWith(color: PLDesign.textMuted)),
          const SizedBox(height: 6),
          Text(
            'Event ID: $eventId',
            style: PLDesign.caption
                .copyWith(color: PLDesign.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PLDesign.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Text(
              TimelineViolationFilter.detailBody(type, metadata),
              style: PLDesign.body.copyWith(height: 1.4, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tTone('timelineEntriesAreTimestampedWhen'),
            style: PLDesign.caption
                .copyWith(color: PLDesign.textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}
