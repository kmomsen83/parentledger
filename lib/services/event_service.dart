import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/case_event.dart';
import '../models/unified_case_event.dart';
import 'case_event_service.dart';
import 'timeline_integrity_service.dart';

/// Single entry for unified case timeline: ledger reads, linkage queries, integrity.
class EventService {
  EventService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _ledger =>
      _db.collection('case_events');

  /// Live unified timeline (newest first).
  static Stream<List<UnifiedCaseEvent>> watchUnifiedTimeline(String caseId) {
    return CaseEventService.watchCaseEvents(caseId).map(
      (events) => events.map(UnifiedCaseEvent.fromCaseEvent).toList(),
    );
  }

  /// Prefer [UnifiedCaseEvent.fromLedgerDoc] when full document is available.
  static UnifiedCaseEvent fromLedgerSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final parsed = CaseEvent.fromDoc(doc);
    return UnifiedCaseEvent.fromLedgerDoc(doc, parsed);
  }

  static Future<TimelineChainVerificationResult> verifyTimelineIntegrity(
    String caseId,
  ) =>
      TimelineIntegrityService.verifyEventChain(caseId);

  /// Paginated older events (newest-first page). Pass [cursor] from previous page's last doc.
  static Future<
          ({
            List<UnifiedCaseEvent> items,
            QueryDocumentSnapshot<Map<String, dynamic>>? nextCursor
          })>
      fetchTimelinePage(
    String caseId, {
    int limit = 40,
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    var q = _ledger
        .where('caseId', isEqualTo: caseId)
        .orderBy('timestampMillis', descending: true)
        .limit(limit);
    if (cursor != null) {
      q = q.startAfterDocument(cursor);
    }
    final snap = await q.get();
    if (snap.docs.isEmpty) {
      return (items: <UnifiedCaseEvent>[], nextCursor: null);
    }
    final ann = await _db
        .collection('case_event_annotations')
        .where('caseId', isEqualTo: caseId)
        .get();
    final tagByEvent = <String, List<String>>{};
    for (final d in ann.docs) {
      final m = d.data();
      final eid = (m['eventId'] ?? '').toString();
      if (eid.isEmpty) continue;
      tagByEvent[eid] = List<String>.from(m['tags'] ?? const <dynamic>[]);
    }
    final items = snap.docs.map((d) {
      var ev = CaseEvent.fromDoc(d);
      final extra = tagByEvent[ev.id];
      if (extra != null && extra.isNotEmpty) {
        final meta = Map<String, dynamic>.from(ev.metadata);
        meta['tags'] = extra;
        ev = CaseEvent(
          id: ev.id,
          caseId: ev.caseId,
          type: ev.type,
          title: ev.title,
          description: ev.description,
          actorId: ev.actorId,
          actorName: ev.actorName,
          createdAt: ev.createdAt,
          metadata: meta,
        );
      }
      return UnifiedCaseEvent.fromLedgerDoc(d, ev);
    }).toList();
    final next = snap.docs.last;
    return (items: items, nextCursor: next);
  }

  static List<UnifiedCaseEvent> eventsForDate(
    List<UnifiedCaseEvent> events,
    DateTime day,
  ) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return events.where((u) {
      final t = u.event.createdAt;
      return !t.isBefore(start) && t.isBefore(end);
    }).toList();
  }

  static List<UnifiedCaseEvent> eventsForExchange(
    List<UnifiedCaseEvent> events,
    String exchangeId,
  ) {
    return events.where((u) {
      if (u.relatedIds.contains(exchangeId)) return true;
      final m = u.event.metadata;
      return m['exchangeId'] == exchangeId || m['scheduleId'] == exchangeId;
    }).toList();
  }

  /// Best-effort: messages whose timestamp falls nearest an exchange scheduled window (same calendar day).
  static List<String> suggestLinkedExchangeIds({
    required UnifiedCaseEvent messageEvent,
    required Iterable<Map<String, dynamic>> exchangeDocs,
  }) {
    final msgTime = messageEvent.event.createdAt;
    String? bestId;
    var bestDelta = Duration(days: 365000);
    for (final m in exchangeDocs) {
      final st = m['scheduledTime'];
      if (st is! Timestamp) continue;
      final exTime = st.toDate();
      if (exTime.year != msgTime.year ||
          exTime.month != msgTime.month ||
          exTime.day != msgTime.day) {
        continue;
      }
      final d = msgTime.difference(exTime).abs();
      if (d < bestDelta) {
        bestDelta = d;
        bestId = m['id'] as String? ?? m['exchangeId'] as String?;
      }
    }
    return bestId == null ? const [] : [bestId];
  }
}
