import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/custody_schedule_rule.dart';

/// Firestore: `cases/{caseId}/custody_schedule/active` + `custody_day_overrides/*`
class CustodyScheduleService {
  CustodyScheduleService._();

  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> _ruleRef(String caseId) =>
      _db.collection('cases').doc(caseId).collection('custody_schedule').doc('active');

  static CollectionReference<Map<String, dynamic>> _overridesCol(String caseId) =>
      _db.collection('cases').doc(caseId).collection('custody_day_overrides');

  static String _dayKey(DateTime localDay) =>
      '${localDay.year.toString().padLeft(4, '0')}-'
      '${localDay.month.toString().padLeft(2, '0')}-'
      '${localDay.day.toString().padLeft(2, '0')}';

  static Future<CustodyScheduleRule> fetchActiveRule(String caseId) async {
    final s = await _ruleRef(caseId).get();
    if (!s.exists) return CustodyScheduleRule.empty;
    return CustodyScheduleRule.fromFirestore(s.data());
  }

  static Stream<CustodyScheduleRule> watchRule(String caseId) {
    return _ruleRef(caseId).snapshots().map((s) {
      if (!s.exists) return CustodyScheduleRule.empty;
      return CustodyScheduleRule.fromFirestore(s.data());
    });
  }

  static Stream<Map<DateTime, String>> watchOverrides(String caseId) {
    return _overridesCol(caseId).snapshots().map((snap) {
      final map = <DateTime, String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final uid = (data['assignedParentUserId'] ?? '').toString();
        if (uid.isEmpty) continue;
        final parts = d.id.split('-');
        if (parts.length != 3) continue;
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (y == null || m == null || day == null) continue;
        map[DateTime(y, m, day)] = uid;
      }
      return map;
    });
  }

  static Future<void> saveRule({
    required String caseId,
    required CustodyScheduleRule rule,
  }) async {
    await _ruleRef(caseId).set(rule.toFirestore(), SetOptions(merge: true));
  }

  static Future<void> clearRule(String caseId) async {
    await _ruleRef(caseId).delete();
  }

  static Future<void> setDayOverride({
    required String caseId,
    required DateTime localDay,
    required String assignedParentUserId,
  }) async {
    await _overridesCol(caseId).doc(_dayKey(localDay)).set(<String, dynamic>{
      'assignedParentUserId': assignedParentUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> clearDayOverride({
    required String caseId,
    required DateTime localDay,
  }) async {
    await _overridesCol(caseId).doc(_dayKey(localDay)).delete();
  }

  /// Manual day override uid, if any (holiday layer checked separately).
  static Future<String?> fetchOverrideUid(
    String caseId,
    DateTime localDay,
  ) async {
    final snap = await _overridesCol(caseId).doc(_dayKey(localDay)).get();
    if (!snap.exists) return null;
    final u = (snap.data()?['assignedParentUserId'] ?? '').toString().trim();
    return u.isEmpty ? null : u;
  }
}
