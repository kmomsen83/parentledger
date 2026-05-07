import 'custody_schedule_generator.dart';
import 'custody_schedule_service.dart';
import 'holiday_service.dart';

/// Custody priority: **holiday** → manual day override → recurring schedule.
class HolidayCustodyResolver {
  HolidayCustodyResolver._();

  /// Effective assigned parent uid for [date] (local calendar day), or null if unknown.
  static Future<String?> getCustodyForDate(
    String caseId,
    DateTime date,
  ) async {
    final local = DateTime(date.year, date.month, date.day);

    final holiday = await HolidayService.getHolidayByDate(caseId, local);
    if (holiday != null && holiday.assignedParentId.isNotEmpty) {
      return holiday.assignedParentId;
    }

    final overrideUid = await CustodyScheduleService.fetchOverrideUid(
      caseId,
      local,
    );
    if (overrideUid != null && overrideUid.isNotEmpty) {
      return overrideUid;
    }

    final rule = await CustodyScheduleService.fetchActiveRule(caseId);
    if (!rule.isConfigured) return null;

    final map = CustodyScheduleGenerator.expand(
      rule: rule,
      rangeStart: local,
      rangeEnd: local,
      overrides: const {},
    );
    return map[local];
  }

  /// Sync version when holiday map + overrides + rule already loaded (e.g. calendar build).
  static String? getCustodyForDateSync({
    required DateTime localDay,
    required Map<DateTime, String> custodyFromScheduleAndOverrides,
    required Map<DateTime, HolidayInfo> holidaysByDay,
  }) {
    final key = DateTime(localDay.year, localDay.month, localDay.day);
    final h = holidaysByDay[key];
    if (h != null && h.assignedParentId.isNotEmpty) return h.assignedParentId;
    return custodyFromScheduleAndOverrides[key];
  }
}

/// Minimal holiday info for calendar merge (avoids importing full model in hot path).
class HolidayInfo {
  const HolidayInfo({
    required this.id,
    required this.name,
    required this.assignedParentId,
  });

  final String id;
  final String name;
  final String assignedParentId;
}
