import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/case_event.dart';
import '../models/timeline_event_model.dart';
import '../timeline/timeline_mapper.dart';

/// Read paths for `case_events` (tamper-resistant ledger). **Writes** go through
/// [EventLoggerService] → `logCaseEvent` only.
class CaseEventService {
  CaseEventService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('case_events');

  static CollectionReference<Map<String, dynamic>> get _annotations =>
      _db.collection('case_event_annotations');

  /// Doc id safe for Firestore (paths may not contain `/`).
  static String annotationDocId(String caseId, String eventId) =>
      '${caseId}_$eventId'.replaceAll('/', '_');

  /// Merge one tag into the overlay doc for a ledger event (e.g. `evidence`).
  static Future<void> mergeAnnotationTag({
    required String caseId,
    required String eventId,
    required String tag,
  }) async {
    final docId = annotationDocId(caseId, eventId);
    final ref = _annotations.doc(docId);
    final snap = await ref.get();
    final existing =
        List<String>.from(snap.data()?['tags'] ?? const <dynamic>[]);
    if (existing.contains(tag)) {
      return;
    }
    existing.add(tag);
    await ref.set(<String, dynamic>{
      'caseId': caseId,
      'eventId': eventId,
      'tags': existing,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Replace tag list for an event overlay (bulk UI).
  static Future<void> setAnnotationTags({
    required String caseId,
    required String eventId,
    required List<String> tags,
  }) async {
    final docId = annotationDocId(caseId, eventId);
    await _annotations.doc(docId).set(<String, dynamic>{
      'caseId': caseId,
      'eventId': eventId,
      'tags': tags,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static CollectionReference<Map<String, dynamic>> _caseTimelineCol(
    String caseId,
  ) =>
      _db.collection('cases').doc(caseId).collection('timeline');

  /// Docs keyed by ledger `case_events` id — only entries with `isEvidence` are merged.
  static Map<String, bool> _evidenceFlagsByEventId(
    QuerySnapshot<Map<String, dynamic>>? tl,
  ) {
    final map = <String, bool>{};
    if (tl == null) {
      return map;
    }
    for (final d in tl.docs) {
      final m = d.data();
      if (!m.containsKey('isEvidence')) {
        continue;
      }
      map[d.id] = m['isEvidence'] == true;
    }
    return map;
  }

  static Map<String, List<String>> _tagsByEventId(
    QuerySnapshot<Map<String, dynamic>>? ann,
  ) {
    final tagByEvent = <String, List<String>>{};
    if (ann == null) {
      return tagByEvent;
    }
    for (final d in ann.docs) {
      final m = d.data();
      final eid = (m['eventId'] ?? '').toString();
      if (eid.isEmpty) {
        continue;
      }
      tagByEvent[eid] = List<String>.from(m['tags'] ?? const <dynamic>[]);
    }
    return tagByEvent;
  }

  static CaseEvent _mergeCaseEventOverlay(
    CaseEvent e,
    Map<String, List<String>> tags,
    Map<String, bool> evidence,
  ) {
    final tagExtra = tags[e.id];
    final ev = evidence[e.id];
    if ((tagExtra == null || tagExtra.isEmpty) && ev == null) {
      return e;
    }
    final meta = Map<String, dynamic>.from(e.metadata);
    if (tagExtra != null && tagExtra.isNotEmpty) {
      meta['tags'] = tagExtra;
    }
    if (ev != null) {
      meta['isEvidence'] = ev;
    }
    return CaseEvent(
      id: e.id,
      caseId: e.caseId,
      type: e.type,
      title: e.title,
      description: e.description,
      actorId: e.actorId,
      actorName: e.actorName,
      createdAt: e.createdAt,
      metadata: meta,
    );
  }

  static TimelineEventModel _mergeTimelineOverlay(
    TimelineEventModel e,
    Map<String, List<String>> tags,
    Map<String, bool> evidence,
  ) {
    final tagExtra = tags[e.id];
    final ev = evidence[e.id];
    if ((tagExtra == null || tagExtra.isEmpty) && ev == null) {
      return e;
    }
    final meta = Map<String, dynamic>.from(e.metadata);
    if (tagExtra != null && tagExtra.isNotEmpty) {
      meta['tags'] = tagExtra;
    }
    if (ev != null) {
      meta['isEvidence'] = ev;
    }
    return TimelineEventModel(
      id: e.id,
      caseId: e.caseId,
      type: e.type,
      title: e.title,
      description: e.description,
      actorName: e.actorName,
      actorId: e.actorId,
      createdAt: e.createdAt,
      metadata: meta,
    );
  }

  static Future<Map<String, List<String>>> _fetchAnnotationTags(
    String caseId,
  ) async {
    final ann =
        await _annotations.where('caseId', isEqualTo: caseId).get();
    return _tagsByEventId(ann);
  }

  static Future<List<CaseEvent>> fetchCaseEvents(String caseId) async {
    final snap = await _events.where('caseId', isEqualTo: caseId).get();
    final tags = await _fetchAnnotationTags(caseId);
    final tlSnap = await _caseTimelineCol(caseId).get();
    final evidence = _evidenceFlagsByEventId(tlSnap);
    final list = snap.docs
        .map(CaseEvent.fromDoc)
        .map((e) => _mergeCaseEventOverlay(e, tags, evidence))
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Same query as [watchCaseEvents], mapped through [TimelineMapper] — newest first.
  static Future<List<TimelineEventModel>> fetchTimelineModels(String caseId) async {
    final snap = await _events.where('caseId', isEqualTo: caseId).get();
    final tags = await _fetchAnnotationTags(caseId);
    final tlSnap = await _caseTimelineCol(caseId).get();
    final evidence = _evidenceFlagsByEventId(tlSnap);
    final list = snap.docs
        .map(TimelineMapper.mapFromFirestore)
        .map((e) => _mergeTimelineOverlay(e, tags, evidence))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Newest first — combines ledger rows with [case_event_annotations] for tags.
  ///
  /// Broadcast so cached/dashboard listeners cannot hit single-subscription double-listen during rebuilds.
  static Stream<List<CaseEvent>> watchCaseEvents(String caseId) {
    final controller = StreamController<List<CaseEvent>>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? lastEv;
    QuerySnapshot<Map<String, dynamic>>? lastAnn;
    QuerySnapshot<Map<String, dynamic>>? lastTl;

    void emit() {
      if (lastEv == null) {
        return;
      }
      final tagByEvent = _tagsByEventId(lastAnn);
      final evidence = _evidenceFlagsByEventId(lastTl);
      final list = lastEv!.docs
          .map(CaseEvent.fromDoc)
          .map((e) => _mergeCaseEventOverlay(e, tagByEvent, evidence))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(list);
    }

    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subEv;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subAnn;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subTl;

    subEv = _events
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .listen((s) {
      lastEv = s;
      emit();
    }, onError: controller.addError);

    subAnn = _annotations
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .listen((s) {
      lastAnn = s;
      emit();
    }, onError: controller.addError);

    subTl = _caseTimelineCol(caseId).snapshots().listen((s) {
      lastTl = s;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await subEv.cancel();
      await subAnn.cancel();
      await subTl.cancel();
    };

    return controller.stream;
  }

  /// Unified timeline stream for UI + PDF — [TimelineEventModel], newest first.
  ///
  /// Broadcast — safe if more than one widget listens during transitions.
  static Stream<List<TimelineEventModel>> watchTimelineModels(String caseId) {
    final controller = StreamController<List<TimelineEventModel>>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? lastEv;
    QuerySnapshot<Map<String, dynamic>>? lastAnn;
    QuerySnapshot<Map<String, dynamic>>? lastTl;

    void emit() {
      if (lastEv == null) {
        return;
      }
      final tagByEvent = _tagsByEventId(lastAnn);
      final evidence = _evidenceFlagsByEventId(lastTl);
      final list = lastEv!.docs
          .map(TimelineMapper.mapFromFirestore)
          .map((e) => _mergeTimelineOverlay(e, tagByEvent, evidence))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(list);
    }

    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subEv;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subAnn;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subTl;

    subEv = _events
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .listen((s) {
      lastEv = s;
      emit();
    }, onError: controller.addError);

    subAnn = _annotations
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .listen((s) {
      lastAnn = s;
      emit();
    }, onError: controller.addError);

    subTl = _caseTimelineCol(caseId).snapshots().listen((s) {
      lastTl = s;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await subEv.cancel();
      await subAnn.cancel();
      await subTl.cancel();
    };

    return controller.stream;
  }

  /// Historical client-side backfill targeted legacy `caseEvents`. Ledger rows are
  /// server-authoritative — use backend migration if historical rows are needed.
  static Future<int> backfillCaseEvents(String caseId) async {
    return 0;
  }
}
