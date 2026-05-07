import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified case-level timeline: `cases/{caseId}/timeline/{eventId}`.
class CaseTimelineService {
  CaseTimelineService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> timelineCol(String caseId) =>
      _db.collection('cases').doc(caseId).collection('timeline');

  /// Evidence overlay for a ledger row (`case_events` doc id). Stored at
  /// `cases/{caseId}/timeline/{eventId}` alongside optional activity-log docs.
  static Future<void> setEvidenceFlag({
    required String caseId,
    required String eventId,
    required bool isEvidence,
  }) async {
    await timelineCol(caseId).doc(eventId).set(<String, dynamic>{
      'caseId': caseId,
      'eventId': eventId,
      'isEvidence': isEvidence,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Types: message_sent, exchange_completed, exchange_checkin_completed,
  /// exchange_scheduled, expense_added, violation_flagged, risk_updated, summary_generated
  static Future<void> logEvent({
    required String caseId,
    required String type,
    required String userId,
    Map<String, dynamic>? metadata,
  }) async {
    await timelineCol(caseId).add(<String, dynamic>{
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': userId,
      'metadata': metadata ?? <String, dynamic>{},
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchTimeline(
    String caseId, {
    int limit = 200,
  }) =>
      timelineCol(caseId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots();

  /// One-shot fetch for reports and attorney summaries (newest first).
  static Future<List<Map<String, dynamic>>> fetchTimeline(
    String caseId, {
    int limit = 200,
  }) async {
    final snap = await timelineCol(caseId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) {
          final m = Map<String, dynamic>.from(d.data());
          m['eventId'] = d.id;
          return m;
        })
        .toList();
  }
}
