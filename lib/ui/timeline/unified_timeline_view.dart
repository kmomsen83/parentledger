import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/design.dart';
import '../../models/unified_case_event.dart';
import '../../services/event_service.dart';

/// Timeline-style feed (not chat bubbles): date separators, jump-to-latest, flagged rows.
class UnifiedTimelineView extends StatefulWidget {
  const UnifiedTimelineView({
    super.key,
    required this.caseId,
    this.showJumpToLatest = true,
  });

  final String caseId;
  final bool showJumpToLatest;

  @override
  State<UnifiedTimelineView> createState() => _UnifiedTimelineViewState();
}

class _UnifiedTimelineViewState extends State<UnifiedTimelineView> {
  final ScrollController _controller = ScrollController();
  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;
  var _loadingOlder = false;
  final List<UnifiedCaseEvent> _older = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder) return;
    setState(() => _loadingOlder = true);
    final page = await EventService.fetchTimelinePage(
      widget.caseId,
      cursor: _cursor,
    );
    if (!mounted) return;
    setState(() {
      _older.addAll(page.items);
      _cursor = page.nextCursor;
      _loadingOlder = false;
    });
  }

  void _jumpLatest() {
    _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UnifiedCaseEvent>>(
      stream: EventService.watchUnifiedTimeline(widget.caseId),
      builder: (context, snap) {
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final live = snap.data ?? const <UnifiedCaseEvent>[];
        final merged = [...live, ..._older];
        merged.sort(
          (a, b) => b.event.createdAt.compareTo(a.event.createdAt),
        );
        if (merged.isEmpty) {
          return Center(
            child: Text(
              'No events yet.',
              style: PLDesign.body.copyWith(color: PLDesign.textMuted),
            ),
          );
        }

        final rows = <Widget>[];
        DateTime? lastDay;
        for (final u in merged) {
          final day = DateTime(
            u.event.createdAt.year,
            u.event.createdAt.month,
            u.event.createdAt.day,
          );
          if (lastDay == null || day != lastDay) {
            lastDay = day;
            rows.add(_DateSeparator(date: day));
          }
          rows.add(_TimelineTile(event: u));
        }

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                  _loadOlder();
                }
                return false;
              },
              child: ListView(
                controller: _controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: rows,
              ),
            ),
            if (widget.showJumpToLatest)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.small(
                  onPressed: _jumpLatest,
                  child: const Icon(Icons.vertical_align_top_rounded),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMEd();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: PLDesign.border.withValues(alpha: 0.6))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              fmt.format(date),
              style: PLDesign.caption.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(child: Divider(color: PLDesign.border.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

String _hm(DateTime t) {
  return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final UnifiedCaseEvent event;

  @override
  Widget build(BuildContext context) {
    final highlight = event.isEvidenceTagged || event.isFlaggedLegal;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? PLDesign.warning.withValues(alpha: 0.08)
            : PLDesign.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? PLDesign.warning.withValues(alpha: 0.45)
              : PLDesign.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.event.title.isEmpty
                      ? event.event.type
                      : event.event.title,
                  style: PLDesign.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _hm(event.event.createdAt),
                style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
              ),
            ],
          ),
          if (event.event.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              event.event.description,
              style: PLDesign.body.copyWith(height: 1.35),
            ),
          ],
          if (event.relatedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Linked: ${event.relatedIds.join(", ")}',
                style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
