import 'package:flutter_test/flutter_test.dart';
import 'package:parentledger/services/shared_calendar_conflict_service.dart';

void main() {
  test('findOverlaps detects same-day overlapping spans', () {
    final day = DateTime(2026, 6, 1, 9, 0);
    final events = [
      CalendarEventSpan(
        start: day,
        end: day.add(const Duration(hours: 2)),
        id: 'a',
      ),
      CalendarEventSpan(
        start: day.add(const Duration(hours: 1)),
        end: day.add(const Duration(hours: 3)),
        id: 'b',
      ),
    ];
    final overlaps = SharedCalendarConflictService.findOverlaps(events);
    expect(overlaps, isNotEmpty);
    expect(overlaps.first.firstIndex, 0);
    expect(overlaps.first.secondIndex, 1);
  });

  test('findOverlaps ignores different days when sameDayOnly', () {
    final a = DateTime(2026, 6, 1, 9, 0);
    final b = DateTime(2026, 6, 2, 9, 0);
    final events = [
      CalendarEventSpan(
        start: a,
        end: a.add(const Duration(hours: 2)),
      ),
      CalendarEventSpan(
        start: b,
        end: b.add(const Duration(hours: 2)),
      ),
    ];
    expect(SharedCalendarConflictService.findOverlaps(events), isEmpty);
  });
}
