import '../models/custody_schedule_rule.dart';

/// Expands [CustodyScheduleRule] into per-day parent uid assignments for a date range.
class CustodyScheduleGenerator {
  CustodyScheduleGenerator._();

  /// 14 `'a'`/`'b'` entries for a standard 2-2-5-5 cycle starting Monday (aligned with [_twoTwoFiveFive]).
  static List<String> preset2255CycleTags({required bool parentAStartsCycle}) {
    return List<String>.generate(14, (i) {
      final isA = _2255ParentA[i];
      final effective = parentAStartsCycle ? isA : !isA;
      return effective ? 'a' : 'b';
    });
  }

  /// Keys are local calendar dates at midnight.
  static Map<DateTime, String> expand({
    required CustodyScheduleRule rule,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    Map<DateTime, String>? overrides,
  }) {
    final out = <DateTime, String>{};
    if (!rule.isConfigured) return out;

    var d = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final end = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    while (!d.isAfter(end)) {
      final key = DateTime(d.year, d.month, d.day);
      final o = overrides?[key];
      if (o != null && o.isNotEmpty) {
        out[key] = o;
      } else {
        final p = _parentForDay(rule, d);
        if (p != null) out[key] = p;
      }
      d = d.add(const Duration(days: 1));
    }
    return out;
  }

  static String? _parentForDay(CustodyScheduleRule r, DateTime day) {
    switch (r.type) {
      case CustodyScheduleRule.weekly:
        return _weekly(r, day);
      case CustodyScheduleRule.biweekly:
        return _biweekly(r, day);
      case CustodyScheduleRule.everyOtherWeekend:
        return _everyOtherWeekend(r, day);
      case CustodyScheduleRule.twoTwoFiveFive:
        return _twoTwoFiveFive(r, day);
      case CustodyScheduleRule.custom:
        return _custom2255Like(r, day);
      default:
        return null;
    }
  }

  static String? _weekly(CustodyScheduleRule r, DateTime day) {
    final a = r.weeklyDaysParentA.contains(day.weekday);
    return a ? r.parentAUserId : r.parentBUserId;
  }

  /// Odd ISO-style week blocks flip who gets the selected weekdays vs complement.
  static String? _biweekly(CustodyScheduleRule r, DateTime day) {
    final start = DateTime(
      r.startDate.year,
      r.startDate.month,
      r.startDate.day,
    );
    final weeks = day.difference(start).inDays ~/ 7;
    final invert = weeks.isOdd;
    final onPattern = r.weeklyDaysParentA.contains(day.weekday);
    final isA = invert ? !onPattern : onPattern;
    return isA ? r.parentAUserId : r.parentBUserId;
  }

  /// Sat=6, Sun=7 — alternating weekend bundles by whole weeks from [startDate].
  static String? _everyOtherWeekend(CustodyScheduleRule r, DateTime day) {
    final isWeekend = day.weekday == DateTime.saturday ||
        day.weekday == DateTime.sunday;
    if (!isWeekend) {
      return _weekly(r, day);
    }
    final start = DateTime(
      r.startDate.year,
      r.startDate.month,
      r.startDate.day,
    );
    final weekIndex = _weekIndexSince(start, day);
    final aWeekend = weekIndex.isEven == r.parentAFirstWeekend;
    return aWeekend ? r.parentAUserId : r.parentBUserId;
  }

  static int _weekIndexSince(DateTime start, DateTime day) {
    final sMon = _mondayOfWeekContaining(start);
    final dMon = _mondayOfWeekContaining(day);
    return dMon.difference(sMon).inDays ~/ 7;
  }

  static DateTime _mondayOfWeekContaining(DateTime d) {
    final offset = d.weekday - DateTime.monday;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: offset));
  }

  /// Standard 14-day 2-2-5-5 pattern (Mon→next Sun).
  static const List<bool> _2255ParentA = [
    true,
    true,
    false,
    false,
    true,
    true,
    true,
    true,
    true,
    false,
    false,
    false,
    false,
    false,
  ];

  static String? _twoTwoFiveFive(CustodyScheduleRule r, DateTime day) {
    final start = DateTime(
      r.startDate.year,
      r.startDate.month,
      r.startDate.day,
    );
    final anchor = _mondayOfWeekContaining(start);
    final idx = day.difference(anchor).inDays;
    if (idx < 0) return _weekly(r, day);
    final phase = ((idx % 14) + 14) % 14;
    var isA = _2255ParentA[phase];
    if (!r.parentAStarts2255Cycle) isA = !isA;
    return isA ? r.parentAUserId : r.parentBUserId;
  }

  static String? _custom2255Like(CustodyScheduleRule r, DateTime day) {
    final cycle = r.customCycle14;
    if (cycle == null || cycle.length != 14) return _weekly(r, day);
    final start = DateTime(
      r.startDate.year,
      r.startDate.month,
      r.startDate.day,
    );
    final anchor = _mondayOfWeekContaining(start);
    final idx = day.difference(anchor).inDays;
    if (idx < 0) return _weekly(r, day);
    final phase = ((idx % 14) + 14) % 14;
    final tag = cycle[phase];
    final isA = tag == 'a';
    return isA ? r.parentAUserId : r.parentBUserId;
  }
}
