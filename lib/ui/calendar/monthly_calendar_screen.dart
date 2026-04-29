import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../design/design.dart';
import '../../models/case_event.dart';
import '../../providers/case_context.dart';
import '../../services/case_event_service.dart';
import '../../services/timeline_violation_filter.dart';
import 'day_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Monthly Calendar'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        rowHeight: 52,
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
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => DayDetailScreen(
                                caseId: caseId,
                                selectedDate: _dayOnly(selected),
                              ),
                            ),
                          );
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
                            final dots = _dotsForDay(dayEvents);
                            if (dots.isEmpty) return null;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: dots
                                    .map(
                                      (k) => Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.symmetric(
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
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Text(
                        'Dots: custody / exchange (yellow), check-in (green), '
                        'issues (red), messaging (blue). Tap a day for the timeline.',
                        style: PLDesign.caption.copyWith(height: 1.35),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
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
