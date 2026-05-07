import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../design/design.dart';
import '../../models/case_event.dart';
import '../../models/custody_schedule_rule.dart';
import '../../models/holiday.dart';
import '../../providers/case_context.dart';
import '../../services/case_switcher_service.dart';
import '../../providers/holiday_provider.dart'
    show HolidayCalendarIndex, holidayEmojiForName;
import '../../services/case_event_service.dart';
import '../../services/custody_schedule_generator.dart';
import '../../services/custody_schedule_service.dart';
import '../../services/holiday_service.dart';
import '../../services/timeline_violation_filter.dart';
import '../../widgets/holiday_modal.dart';
import '../widgets/premium_upgrade_sheet.dart';
import 'day_detail_screen.dart';
import 'set_custody_schedule_sheet.dart';

/// Data-driven month grid backed by [caseEvents]. Swipe or header buttons change month.
///
/// Navigation entry points use [CalendarMonthViewScreen] (see `calendar_month_view_screen.dart`).
class CalendarMonthViewScreen extends StatefulWidget {
  const CalendarMonthViewScreen({super.key});

  @override
  State<CalendarMonthViewScreen> createState() =>
      _CalendarMonthViewScreenState();
}

class _CalendarMonthViewScreenState extends State<CalendarMonthViewScreen> {
  DateTime _focusedDay = DateTime.now();

  List<CaseEvent>? _groupedSourceRef;
  Map<DateTime, List<CaseEvent>>? _groupedByDayCache;

  Map<DateTime, List<CaseEvent>> _groupedForSnapshot(List<CaseEvent> events) {
    if (_groupedSourceRef != null &&
        identical(_groupedSourceRef, events) &&
        _groupedByDayCache != null) {
      return _groupedByDayCache!;
    }
    _groupedSourceRef = events;
    _groupedByDayCache = _groupByLocalDay(events);
    return _groupedByDayCache!;
  }

  static DateTime _dayOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static Map<DateTime, List<CaseEvent>> _groupByLocalDay(
    Iterable<CaseEvent> events,
  ) {
    final map = <DateTime, List<CaseEvent>>{};
    for (final e in events) {
      final t = e.createdAt.toLocal();
      final day = DateTime(t.year, t.month, t.day);
      map.putIfAbsent(day, () => []).add(e);
    }
    return map;
  }

  static bool _isExchangeSchedule(CaseEvent e) =>
      e.type == CaseEventTypes.scheduleCreated ||
      e.type == CaseEventTypes.scheduleUpdated ||
      e.type == 'exchange';

  static bool _isExchangeCheckin(CaseEvent e) =>
      e.metadata['eventSubtype'] == 'exchange_checkin_completed' ||
      (e.type == CaseEventTypes.statusChange &&
          e.title.toLowerCase().contains('exchange check-in'));

  static bool _isRedCaseEvent(CaseEvent e) =>
      e.type == CaseEventTypes.expenseDenied ||
      e.type == 'violation' ||
      TimelineViolationFilter.caseEventIsViolation(e);

  static bool _hasBlueMessaging(List<CaseEvent> dayEvents) {
    if (dayEvents.isEmpty) return false;
    return dayEvents.every((e) => e.isMessageLike);
  }

  /// Priority red > yellow > green > blue; max three dots.
  static List<_DotKind> _dotsForDay(List<CaseEvent> events) {
    final hasYellow = events.any(_isExchangeSchedule);
    final hasGreen = events.any(_isExchangeCheckin);
    final hasRed = events.any(_isRedCaseEvent);
    final hasBlue = _hasBlueMessaging(events);

    final ordered = <_DotKind>[];
    if (hasRed) ordered.add(_DotKind.red);
    if (hasYellow) ordered.add(_DotKind.yellow);
    if (hasGreen) ordered.add(_DotKind.green);
    if (hasBlue) ordered.add(_DotKind.blue);

    if (ordered.length <= 3) return ordered;

    const priority = [
      _DotKind.red,
      _DotKind.yellow,
      _DotKind.green,
      _DotKind.blue,
    ];
    final out = <_DotKind>[];
    for (final k in priority) {
      if (ordered.contains(k)) out.add(k);
      if (out.length >= 3) break;
    }
    return out;
  }

  static Color _dotColor(_DotKind k) {
    switch (k) {
      case _DotKind.red:
        return PLDesign.danger;
      case _DotKind.yellow:
        return PLDesign.warning;
      case _DotKind.green:
        return PLDesign.success;
      case _DotKind.blue:
        return PLDesign.primary;
    }
  }

  static String _complianceLabel(List<CaseEvent> events) {
    final scheduledIds = <String>{};
    for (final e in events) {
      if (e.type == CaseEventTypes.scheduleCreated || e.type == 'exchange') {
        final id =
            '${e.metadata['exchangeId'] ?? e.metadata['scheduleId'] ?? ''}'.trim();
        if (id.isNotEmpty) scheduledIds.add(id);
      }
    }
    final completedIds = <String>{};
    for (final e in events) {
      if (e.type != CaseEventTypes.statusChange) continue;
      final title = e.title.toLowerCase();
      if (!title.contains('exchange completed')) continue;
      final id = '${e.metadata['exchangeId'] ?? ''}'.trim();
      if (id.isNotEmpty) completedIds.add(id);
    }
    if (scheduledIds.isEmpty) return '—';
    final matched =
        scheduledIds.where((id) => completedIds.contains(id)).length;
    final pct = (100 * matched / scheduledIds.length).round();
    return '$pct%';
  }

  static int _violationCount(List<CaseEvent> events) =>
      events.where(_isRedCaseEvent).length;

  static int _exchangeActivityCount(List<CaseEvent> events) {
    var n = 0;
    for (final e in events) {
      if (_isExchangeSchedule(e)) {
        n++;
        continue;
      }
      if (e.type == CaseEventTypes.statusChange) {
        final t = e.title.toLowerCase();
        if (t.contains('exchange completed') ||
            t.contains('exchange check-in')) {
          n++;
        }
      }
    }
    return n;
  }

  void _goMonth(int delta) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + delta);
    });
  }

  static Color? _custodyBarColor(String? uid, CustodyScheduleRule rule) {
    if (uid == null || !rule.isConfigured) return null;
    if (uid == rule.parentAUserId) return PLDesign.primary;
    if (uid == rule.parentBUserId) return PLDesign.ai;
    return PLDesign.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final switcher = context.watch<CaseSwitcherService>();
    final caseId = session.isAttorney
        ? (switcher.selectedCaseId ?? session.caseId)
        : session.caseId;

    final scheduleParentLocked =
        !session.isAttorney && !session.unlockedParentPremiumFeatures;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Monthly Calendar'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        actions: [
          IconButton(
            tooltip: 'Add holiday',
            icon: const Icon(Icons.celebration_outlined),
            onPressed: caseId == null || caseId.isEmpty
                ? null
                : scheduleParentLocked
                    ? () {
                        showPremiumUpgradeSheet(
                          context,
                          feature: DashboardPremiumFeature.calendarScheduling,
                        );
                      }
                    : () async {
                        try {
                          final r = await CustodyScheduleService.fetchActiveRule(
                            caseId,
                          );
                          if (!context.mounted) return;
                          await showCreateHolidayDialog(
                            context: context,
                            caseId: caseId,
                            rule: r,
                            initialDate: _focusedDay,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not load schedule: $e')),
                          );
                        }
                      },
          ),
        ],
      ),
      body: caseId == null || caseId.isEmpty
          ? Center(
              child: Text(
                'No case loaded',
                style: PLDesign.body.copyWith(color: PLDesign.textMuted),
              ),
            )
          : StreamBuilder<List<CaseEvent>>(
              stream: CaseEventService.watchCaseEvents(caseId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load events: ${snap.error}',
                        style: PLDesign.body.copyWith(color: PLDesign.danger),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final events = snap.data ?? [];
                final byDay = _groupedForSnapshot(events);

                final compliance = _complianceLabel(events);
                final violations = _violationCount(events);
                final exchangeTotal = _exchangeActivityCount(events);

                return StreamBuilder<CustodyScheduleRule>(
                  stream: CustodyScheduleService.watchRule(caseId),
                  builder: (context, ruleSnap) {
                    final rule =
                        ruleSnap.data ?? CustodyScheduleRule.empty;
                    return StreamBuilder<Map<DateTime, String>>(
                      stream: CustodyScheduleService.watchOverrides(caseId),
                      builder: (context, ovSnap) {
                        final overrides =
                            ovSnap.data ?? <DateTime, String>{};
                        final rangeStart = DateTime(
                          _focusedDay.year,
                          _focusedDay.month,
                          1,
                        );
                        final rangeEnd = DateTime(
                          _focusedDay.year,
                          _focusedDay.month + 1,
                          0,
                        );
                        final custodyByDay = rule.isConfigured
                            ? CustodyScheduleGenerator.expand(
                                rule: rule,
                                rangeStart: rangeStart,
                                rangeEnd: rangeEnd,
                                overrides: overrides,
                              )
                            : <DateTime, String>{};

                        return StreamBuilder<List<Holiday>>(
                          stream: HolidayService.watchHolidaysForMonth(
                            caseId,
                            _focusedDay,
                          ),
                          builder: (context, holSnap) {
                            final holidays = holSnap.data ?? [];
                            final holidayByDay =
                                HolidayCalendarIndex.holidaysByLocalDay(
                              holidays,
                            );

                            return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StreamBuilder<List<Holiday>>(
                      stream: HolidayService.watchUpcomingHolidays(caseId),
                      builder: (context, upSnap) {
                        final upcoming = upSnap.data ?? [];
                        if (upcoming.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final next = upcoming.first;
                        final who = next.assignedParentId == rule.parentAUserId
                            ? 'Parent A'
                            : (next.assignedParentId == rule.parentBUserId
                                ? 'Parent B'
                                : 'Assigned parent');
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                          child: Material(
                            color: PLDesign.card,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: rule.isConfigured
                                  ? () => showHolidayDetailSheet(
                                        context: context,
                                        caseId: caseId,
                                        holiday: next,
                                        rule: rule,
                                      )
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      holidayEmojiForName(next.name),
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Next: ${next.name}',
                                            style: PLDesign.body.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '${Holiday.dateKeyFor(next.dateLocal)} · $who',
                                            style: PLDesign.caption.copyWith(
                                              color: PLDesign.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: rule.isConfigured
                                          ? () {
                                              if (scheduleParentLocked) {
                                                showPremiumUpgradeSheet(
                                                  context,
                                                  feature:
                                                      DashboardPremiumFeature
                                                          .calendarScheduling,
                                                );
                                                return;
                                              }
                                              showHolidayDetailSheet(
                                                context: context,
                                                caseId: caseId,
                                                holiday: next,
                                                rule: rule,
                                              );
                                            }
                                          : null,
                                      child: const Text('Propose change'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              PLDesign.primary.withValues(alpha: 0.22),
                              PLDesign.card,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: PLDesign.r20,
                          border: Border.all(color: PLDesign.border),
                          boxShadow: PLDesign.softShadow,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _MetricBlock(
                                label: 'Compliance',
                                value: compliance,
                                hint: 'completed / scheduled',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 44,
                              color: PLDesign.border,
                            ),
                            Expanded(
                              child: _MetricBlock(
                                label: 'Violations',
                                value: '$violations',
                                hint: 'denied / flags',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 44,
                              color: PLDesign.border,
                            ),
                            Expanded(
                              child: _MetricBlock(
                                label: 'Exchanges',
                                value: '$exchangeTotal',
                                hint: 'schedule & activity',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: OutlinedButton.icon(
                        onPressed: scheduleParentLocked
                            ? () => showPremiumUpgradeSheet(
                                  context,
                                  feature: DashboardPremiumFeature
                                      .calendarScheduling,
                                )
                            : () => showSetCustodyScheduleSheet(
                                  context,
                                  caseId: caseId,
                                ),
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Set custody schedule'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PLDesign.textPrimary,
                          side: const BorderSide(color: PLDesign.border),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => _goMonth(-1),
                            child: const Text('< Prev'),
                          ),
                          Expanded(
                            child: Text(
                              DateFormat.yMMMM().format(_focusedDay),
                              textAlign: TextAlign.center,
                              style: PLDesign.sectionTitle.copyWith(fontSize: 16),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _goMonth(1),
                            child: const Text('Next >'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TableCalendar<CaseEvent>(
                        firstDay: DateTime.utc(2018, 1, 1),
                        lastDay: DateTime.utc(2035, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: CalendarFormat.month,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        headerVisible: false,
                        daysOfWeekVisible: true,
                        startingDayOfWeek: StartingDayOfWeek.sunday,
                        availableGestures: AvailableGestures.horizontalSwipe,
                        rowHeight: 56,
                        sixWeekMonthsEnforced: false,
                        eventLoader: (day) {
                          final key = _dayOnly(day);
                          return byDay[key] ?? const <CaseEvent>[];
                        },
                        onPageChanged: (focused) {
                          setState(() => _focusedDay = focused);
                        },
                        onDaySelected: (selected, focused) {
                          setState(() => _focusedDay = focused);
                          final key = _dayOnly(selected);
                          final hol = holidayByDay[key];
                          if (hol != null) {
                            showHolidayDetailSheet(
                              context: context,
                              caseId: caseId,
                              holiday: hol,
                              rule: rule,
                            );
                          } else {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => DayDetailScreen(
                                  caseId: caseId,
                                  selectedDate: key,
                                ),
                              ),
                            );
                          }
                        },
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: true,
                          weekendTextStyle: TextStyle(
                            color: PLDesign.textMuted.withValues(alpha: 0.85),
                          ),
                          defaultTextStyle: const TextStyle(
                            color: PLDesign.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          cellMargin: const EdgeInsets.all(4),
                          markersAlignment: Alignment.bottomCenter,
                          markersMaxCount: 3,
                          markerDecoration: const BoxDecoration(),
                          todayDecoration: BoxDecoration(
                            color: PLDesign.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: PLDesign.primary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: PLDesign.primary.withValues(alpha: 0.35),
                                blurRadius: 14,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          defaultDecoration: BoxDecoration(
                            color: PLDesign.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: PLDesign.border),
                          ),
                          outsideDecoration: BoxDecoration(
                            color: PLDesign.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: PLDesign.border.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: PLDesign.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          weekendStyle: TextStyle(
                            color: PLDesign.textMuted.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders<CaseEvent>(
                          markerBuilder: (context, day, dayEvents) {
                            final key = _dayOnly(day);
                            final hol = holidayByDay[key];
                            final custodyUid = hol?.assignedParentId ??
                                custodyByDay[key];
                            final barColor =
                                _custodyBarColor(custodyUid, rule);
                            final dots = _dotsForDay(dayEvents);
                            final emoji = hol != null
                                ? holidayEmojiForName(hol.name)
                                : null;
                            if (barColor == null &&
                                dots.isEmpty &&
                                emoji == null) {
                              return null;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (dots.isNotEmpty)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: dots
                                          .map(
                                            (k) => Container(
                                              width: 6,
                                              height: 6,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _dotColor(k),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  if (barColor != null || emoji != null)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: dots.isNotEmpty ? 3 : 0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (barColor != null)
                                            Container(
                                              height: 4,
                                              width: 26,
                                              decoration: BoxDecoration(
                                                color: barColor,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          if (emoji != null) ...[
                                            if (barColor != null)
                                              const SizedBox(width: 4),
                                            Text(
                                              emoji,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Text(
                        'Bottom strip: custody (holidays override schedule). '
                        'Dots: exchange (yellow), check-in (green), issues (red), messaging (blue). '
                        'Holiday icon when set. Tap a holiday for swap/time proposals or another day for details.',
                        style: PLDesign.caption.copyWith(height: 1.35),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

enum _DotKind { red, yellow, green, blue }

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: PLDesign.caption.copyWith(
            color: PLDesign.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(value, style: PLDesign.statNumber.copyWith(fontSize: 22)),
        const SizedBox(height: 2),
        Text(
          hint,
          style: PLDesign.caption.copyWith(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
