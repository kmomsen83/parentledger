import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/holiday.dart';
import '../models/holiday_proposal.dart';

/// Firestore: `cases/{caseId}/holidays/*` and `holiday_proposals/*`.
class HolidayService {
  HolidayService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> holidaysCol(String caseId) =>
      _db.collection('cases').doc(caseId).collection('holidays');

  static CollectionReference<Map<String, dynamic>> proposalsCol(String caseId) =>
      _db.collection('cases').doc(caseId).collection('holiday_proposals');

  static String _monthStartKey(DateTime month) {
    final d = DateTime(month.year, month.month, 1);
    return Holiday.dateKeyFor(d);
  }

  static String _monthEndKey(DateTime month) {
    final last = DateTime(month.year, month.month + 1, 0);
    return Holiday.dateKeyFor(last);
  }

  /// All holidays in [month] (any day in that calendar month).
  static Future<List<Holiday>> getHolidaysForMonth(
    String caseId,
    DateTime month,
  ) async {
    final start = _monthStartKey(month);
    final end = _monthEndKey(month);
    final snap = await holidaysCol(caseId)
        .where('dateKey', isGreaterThanOrEqualTo: start)
        .where('dateKey', isLessThanOrEqualTo: end)
        .get();
    final list = snap.docs
        .map((d) => Holiday.fromFirestore(d.id, d.data()))
        .toList()
      ..sort((a, b) => a.dateLocal.compareTo(b.dateLocal));
    return list;
  }

  /// Live stream for the visible month — single listener for calendar performance.
  static Stream<List<Holiday>> watchHolidaysForMonth(
    String caseId,
    DateTime month,
  ) {
    final start = _monthStartKey(month);
    final end = _monthEndKey(month);
    return holidaysCol(caseId)
        .where('dateKey', isGreaterThanOrEqualTo: start)
        .where('dateKey', isLessThanOrEqualTo: end)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => Holiday.fromFirestore(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.dateLocal.compareTo(b.dateLocal));
      return list;
    });
  }

  /// Upcoming holidays from today forward — filters client-side for predictable indexes at scale.
  static Stream<List<Holiday>> watchUpcomingHolidays(
    String caseId, {
    int limit = 12,
  }) {
    return holidaysCol(caseId).snapshots().map((snap) {
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final list = snap.docs
          .map((d) => Holiday.fromFirestore(d.id, d.data()))
          .where((h) {
            final dl = DateTime(
              h.dateLocal.year,
              h.dateLocal.month,
              h.dateLocal.day,
            );
            return !dl.isBefore(today);
          })
          .toList()
        ..sort((a, b) => a.dateLocal.compareTo(b.dateLocal));
      if (list.length <= limit) return list;
      return list.take(limit).toList();
    });
  }

  static Future<Holiday?> getHolidayByDate(String caseId, DateTime localDay) async {
    final key = Holiday.dateKeyFor(
      DateTime(localDay.year, localDay.month, localDay.day),
    );
    final snap = await holidaysCol(caseId)
        .where('dateKey', isEqualTo: key)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Holiday.fromFirestore(d.id, d.data());
  }

  static Future<String> createHoliday(Holiday draft) async {
    final ref = holidaysCol(draft.caseId).doc();
    final full = Holiday(
      id: ref.id,
      caseId: draft.caseId,
      name: draft.name,
      dateLocal: draft.dateLocal,
      assignedParentId: draft.assignedParentId,
      notes: draft.notes,
      isOverride: draft.isOverride,
      createdAt: draft.createdAt,
      updatedAt: draft.updatedAt,
    );
    await ref.set(full.toFirestore(isCreate: true));
    return ref.id;
  }

  static Future<void> updateHoliday(Holiday holiday) async {
    await holidaysCol(holiday.caseId)
        .doc(holiday.id)
        .set(holiday.toFirestore(isCreate: false), SetOptions(merge: true));
  }

  static Future<void> deleteHoliday({
    required String caseId,
    required String holidayId,
  }) async {
    await holidaysCol(caseId).doc(holidayId).delete();
  }

  static Future<void> createHolidayProposal({
    required String caseId,
    required String holidayId,
    required String proposedBy,
    required String targetParentId,
    required String newParentId,
    String? message,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final ref = proposalsCol(caseId).doc();
    await ref.set(<String, dynamic>{
      'caseId': caseId,
      'holidayId': holidayId,
      'proposedBy': proposedBy,
      'targetParentId': targetParentId,
      'newParentId': newParentId,
      'message': message ?? '',
      'status': HolidayProposal.pending,
      if (startTime != null) 'startTime': Timestamp.fromDate(startTime),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> acceptProposal({
    required String caseId,
    required String proposalId,
  }) async {
    final pref = proposalsCol(caseId).doc(proposalId);
    final pSnap = await pref.get();
    if (!pSnap.exists) throw StateError('Proposal not found');
    final p = HolidayProposal.fromFirestore(proposalId, pSnap.data()!);
    if (p.status != HolidayProposal.pending) {
      throw StateError('Proposal is no longer pending');
    }
    final hRef = holidaysCol(caseId).doc(p.holidayId);
    final batch = _db.batch();
    batch.update(hRef, <String, dynamic>{
      'assignedParentId': p.newParentId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(pref, <String, dynamic>{
      'status': HolidayProposal.accepted,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> denyProposal({
    required String caseId,
    required String proposalId,
  }) async {
    await proposalsCol(caseId).doc(proposalId).update(<String, dynamic>{
      'status': HolidayProposal.denied,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<HolidayProposal>> watchPendingProposalsForUser({
    required String caseId,
    required String uid,
  }) {
    return proposalsCol(caseId)
        .where('status', isEqualTo: HolidayProposal.pending)
        .where('targetParentId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs
            .map((d) => HolidayProposal.fromFirestore(d.id, d.data()))
            .toList());
  }
}
