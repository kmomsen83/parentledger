import '../models/holiday.dart';
import '../services/holiday_custody_resolver.dart' show HolidayInfo;

/// Pure helpers for calendar UIs (no ChangeNotifier — avoids redundant global state).
/// Month holidays stream lives in [HolidayService.watchHolidaysForMonth].
class HolidayCalendarIndex {
  HolidayCalendarIndex._();

  /// O(1) lookup by local calendar day.
  static Map<DateTime, Holiday> holidaysByLocalDay(Iterable<Holiday> holidays) {
    return {
      for (final h in holidays)
        DateTime(h.dateLocal.year, h.dateLocal.month, h.dateLocal.day): h,
    };
  }

  /// Maps for [HolidayCustodyResolver.getCustodyForDateSync].
  static Map<DateTime, HolidayInfo> toHolidayInfoMap(Iterable<Holiday> holidays) {
    return {
      for (final h in holidays)
        DateTime(h.dateLocal.year, h.dateLocal.month, h.dateLocal.day): HolidayInfo(
          id: h.id,
          name: h.name,
          assignedParentId: h.assignedParentId,
        ),
    };
  }

  /// Next holiday on or after [from] (local dates).
  static Holiday? nextUpcoming(
    Iterable<Holiday> holidays,
    DateTime from,
  ) {
    final start = DateTime(from.year, from.month, from.day);
    Holiday? best;
    for (final h in holidays) {
      final d = DateTime(h.dateLocal.year, h.dateLocal.month, h.dateLocal.day);
      if (d.isBefore(start)) continue;
      if (best == null || d.isBefore(DateTime(
            best.dateLocal.year,
            best.dateLocal.month,
            best.dateLocal.day,
          ))) {
        best = h;
      }
    }
    return best;
  }
}

/// Emoji hint for common US/legal holidays; fallback festive icon.
String holidayEmojiForName(String name) {
  final n = name.toLowerCase();
  if (n.contains('christmas')) return '🎄';
  if (n.contains('thanksgiving')) return '🦃';
  if (n.contains('easter')) return '🐣';
  if (n.contains('independence') || n.contains('july 4')) return '🎆';
  if (n.contains('new year')) return '🎉';
  if (n.contains('memorial')) return '🇺🇸';
  if (n.contains('labor')) return '⚒️';
  if (n.contains('halloween')) return '🎃';
  if (n.contains('mother')) return '💐';
  if (n.contains('father')) return '👔';
  return '📌';
}
