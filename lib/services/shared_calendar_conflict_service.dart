/// Parenting calendar overlap detection for `cases/{caseId}/calendar_events` (or equivalent
/// event maps). Pure logic — no Firestore reads.
class SharedCalendarConflictService {
  SharedCalendarConflictService._();

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endExclusive(DateTime start, DateTime end) {
    if (end.isAfter(start)) return end;
    return start.add(const Duration(minutes: 1));
  }

  /// Returns pairs of indices into [events] that overlap in time on the same calendar day
  /// when [sameDayOnly] is true (custody handoffs typically day-bounded in UI).
  static List<CalendarEventOverlap> findOverlaps(
    List<CalendarEventSpan> events, {
    bool sameDayOnly = true,
  }) {
    final out = <CalendarEventOverlap>[];
    for (var i = 0; i < events.length; i++) {
      for (var j = i + 1; j < events.length; j++) {
        final a = events[i];
        final b = events[j];
        if (sameDayOnly && _dayStart(a.start) != _dayStart(b.start)) continue;
        final aEnd = _endExclusive(a.start, a.end);
        final bEnd = _endExclusive(b.start, b.end);
        if (a.start.isBefore(bEnd) && b.start.isBefore(aEnd)) {
          out.add(CalendarEventOverlap(firstIndex: i, secondIndex: j));
        }
      }
    }
    return out;
  }
}

class CalendarEventSpan {
  const CalendarEventSpan({
    required this.start,
    required this.end,
    this.id,
  });

  final DateTime start;
  final DateTime end;
  final String? id;
}

class CalendarEventOverlap {
  const CalendarEventOverlap({
    required this.firstIndex,
    required this.secondIndex,
  });

  final int firstIndex;
  final int secondIndex;
}
