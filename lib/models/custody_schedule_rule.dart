import 'package:cloud_firestore/cloud_firestore.dart';

/// Stored under `cases/{caseId}/custody_schedule/active`.
class CustodyScheduleRule {
  const CustodyScheduleRule({
    required this.type,
    required this.startDate,
    required this.parentAUserId,
    required this.parentBUserId,
    required this.weeklyDaysParentA,
    this.customCycle14,
    this.parentAFirstWeekend = true,
    this.parentAStarts2255Cycle = true,
    this.updatedAt,
  });

  /// weekly | biweekly | every_other_weekend | two_two_five_five | custom
  final String type;
  final DateTime startDate;

  /// Parents whose custody assignment rotates according to [type].
  final String parentAUserId;
  final String parentBUserId;

  /// Dart [DateTime.weekday]: Mon=1 … Sun=7 — days parent A has custody (weekly/biweekly).
  final List<int> weeklyDaysParentA;

  /// Exactly 14 entries: `'a'` or `'b'` for parent A/B assignment per cycle day.
  final List<String>? customCycle14;

  /// For [everyOtherWeekend]: if true, parent A has the first Sat–Sun block after [startDate].
  final bool parentAFirstWeekend;

  /// For [two_two_five_five]: when true, parent A gets indices matching standard 2-2-5-5 phase 0.
  final bool parentAStarts2255Cycle;

  final DateTime? updatedAt;

  static const weekly = 'weekly';
  static const biweekly = 'biweekly';
  static const everyOtherWeekend = 'every_other_weekend';
  static const twoTwoFiveFive = 'two_two_five_five';
  static const custom = 'custom';

  bool get isEmpty =>
      parentAUserId.isEmpty || parentBUserId.isEmpty || type.isEmpty;

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'type': type,
      'startDate': Timestamp.fromDate(startDate),
      'parentAUserId': parentAUserId,
      'parentBUserId': parentBUserId,
      'weeklyDaysParentA': weeklyDaysParentA,
      if (customCycle14 != null) 'customCycle14': customCycle14,
      'parentAFirstWeekend': parentAFirstWeekend,
      'parentAStarts2255Cycle': parentAStarts2255Cycle,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory CustodyScheduleRule.fromFirestore(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return empty;
    }
    final sd = data['startDate'];
    DateTime start = DateTime.now();
    if (sd is Timestamp) start = sd.toDate();

    final wd = data['weeklyDaysParentA'];
    final weekly = <int>[];
    if (wd is List) {
      for (final x in wd) {
        if (x is int) weekly.add(x);
        if (x is num) weekly.add(x.toInt());
      }
    }

    List<String>? cycle;
    final c = data['customCycle14'];
    if (c is List && c.length == 14) {
      cycle = c.map((e) => e.toString().toLowerCase()).toList();
    }

    final t = (data['type'] ?? '').toString();
    final rule = CustodyScheduleRule(
      type: t,
      startDate: start,
      parentAUserId: (data['parentAUserId'] ?? '').toString(),
      parentBUserId: (data['parentBUserId'] ?? '').toString(),
      weeklyDaysParentA: weekly,
      customCycle14: cycle,
      parentAFirstWeekend: data['parentAFirstWeekend'] != false,
      parentAStarts2255Cycle: data['parentAStarts2255Cycle'] != false,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
    if (t.isEmpty) return empty;
    return rule;
  }

  static final CustodyScheduleRule empty = CustodyScheduleRule(
    type: '',
    startDate: DateTime(1970, 1, 1),
    parentAUserId: '',
    parentBUserId: '',
    weeklyDaysParentA: const [],
  );

  bool get isConfigured =>
      type.isNotEmpty &&
      parentAUserId.isNotEmpty &&
      parentBUserId.isNotEmpty &&
      parentAUserId != parentBUserId;
}
