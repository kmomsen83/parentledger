import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';
import '../../design/design.dart';
import '../../models/case_event.dart';
import '../../models/custody_schedule_rule.dart';
import '../../services/case_event_service.dart';
import '../../models/holiday.dart';
import '../../providers/holiday_provider.dart' show holidayEmojiForName;
import '../../services/custody_schedule_generator.dart';
import '../../services/custody_schedule_service.dart';
import '../../services/holiday_service.dart';
import '../../services/timeline_actor_resolver.dart';
import '../../providers/case_context.dart';
import '../conversation_thread_screen.dart';
import '../documents_library_screen.dart';
import '../proposals/create_proposal_screen.dart';
import '../widgets/premium_upgrade_sheet.dart';
import '../../services/case_messaging_service.dart';

/// Calendar day hub: quick actions plus an immutable audit list for that date.
class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({
    super.key,
    required this.caseId,
    required this.selectedDate,
  });

  final String caseId;

  /// Local calendar date (year/month/day only).
  final DateTime selectedDate;

  static bool _sameLocalDay(CaseEvent e, DateTime day) {
    final t = e.createdAt.toLocal();
    return t.year == day.year &&
        t.month == day.month &&
        t.day == day.day;
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat.yMMMd().format(selectedDate);

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Day overview'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayLabel,
                  style: PLDesign.sectionTitle.copyWith(
                    fontSize: 22,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Time-stamped and immutable record',
                  style: PLDesign.caption.copyWith(
                    color: PLDesign.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _CustodyDayScheduleCard(
              caseId: caseId,
              selectedDate: selectedDate,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DayActionPanel(
              caseId: caseId,
              selectedDate: selectedDate,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Divider(
              height: 1,
              thickness: 1,
              color: PLDesign.border.withValues(alpha: 0.85),
            ),
          ),
          Expanded(
            child: DayTimelineList(
              caseId: caseId,
              selectedDate: selectedDate,
              sameDay: _sameLocalDay,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustodyDayScheduleCard extends StatelessWidget {
  const _CustodyDayScheduleCard({
    required this.caseId,
    required this.selectedDate,
  });

  final String caseId;
  final DateTime selectedDate;

  static DateTime _dayOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static String _roleLabel(String? uid, CustodyScheduleRule rule) {
    if (uid == null || uid.isEmpty) return '—';
    if (uid == rule.parentAUserId) return 'Parent A';
    if (uid == rule.parentBUserId) return 'Parent B';
    return uid;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final scheduleLocked =
        !session.isAttorney && !session.unlockedParentPremiumFeatures;

    return StreamBuilder<List<Holiday>>(
      stream: HolidayService.watchHolidaysForMonth(caseId, selectedDate),
      builder: (context, holSnap) {
        final holidays = holSnap.data ?? [];
        final day = _dayOnly(selectedDate);
        Holiday? holiday;
        for (final h in holidays) {
          if (_dayOnly(h.dateLocal) == day) {
            holiday = h;
            break;
          }
        }

        return StreamBuilder<CustodyScheduleRule>(
          stream: CustodyScheduleService.watchRule(caseId),
          builder: (context, rs) {
            final rule = rs.data ?? CustodyScheduleRule.empty;
            return StreamBuilder<Map<DateTime, String>>(
              stream: CustodyScheduleService.watchOverrides(caseId),
              builder: (context, os) {
                final overrides = os.data ?? {};

                if (!rule.isConfigured) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PLDesign.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PLDesign.border),
                ),
                child: Text(
                  'No repeating custody schedule yet. From Monthly Calendar, '
                  'tap “Set custody schedule” to define your pattern.',
                  style: PLDesign.caption.copyWith(height: 1.35),
                ),
              );
            }

            final scheduleEffective = CustodyScheduleGenerator.expand(
              rule: rule,
              rangeStart: day,
              rangeEnd: day,
              overrides: overrides,
            )[day];

            final effective = holiday != null
                ? holiday.assignedParentId
                : scheduleEffective;

            final overrideUid = overrides[day];
            String dropValue;
            if (overrideUid == null) {
              dropValue = 'schedule';
            } else if (overrideUid == rule.parentAUserId) {
              dropValue = 'a';
            } else if (overrideUid == rule.parentBUserId) {
              dropValue = 'b';
            } else {
              dropValue = 'schedule';
            }

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PLDesign.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PLDesign.border),
                boxShadow: PLDesign.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.home_work_outlined,
                        color: PLDesign.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Custody this day',
                          style: PLDesign.sectionTitle.copyWith(fontSize: 16),
                        ),
                      ),
                      if (holiday != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: PLDesign.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Holiday',
                            style: PLDesign.caption.copyWith(
                              color: PLDesign.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else if (overrideUid != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: PLDesign.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Override',
                            style: PLDesign.caption.copyWith(
                              color: PLDesign.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (holiday != null) ...[
                    Row(
                      children: [
                        Text(
                          holidayEmojiForName(holiday.name),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            holiday.name,
                            style: PLDesign.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    _roleLabel(effective, rule),
                    style: PLDesign.body.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    holiday != null
                        ? 'Holiday custody (overrides schedule & day overrides)'
                        : 'Manual override',
                    style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: PLDesign.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: PLDesign.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: PLDesign.border),
                      ),
                    ),
                    value: dropValue,
                    items: const [
                      DropdownMenuItem(
                        value: 'schedule',
                        child: Text('Follow repeating schedule'),
                      ),
                      DropdownMenuItem(
                        value: 'a',
                        child: Text('Force Parent A'),
                      ),
                      DropdownMenuItem(
                        value: 'b',
                        child: Text('Force Parent B'),
                      ),
                    ],
                    onChanged: holiday != null
                        ? null
                        : scheduleLocked
                            ? (_) {
                                showPremiumUpgradeSheet(
                                  context,
                                  feature:
                                      DashboardPremiumFeature.calendarScheduling,
                                );
                              }
                            : (v) async {
                                if (v == null) return;
                                try {
                                  if (v == 'schedule') {
                                    await CustodyScheduleService.clearDayOverride(
                                      caseId: caseId,
                                      localDay: day,
                                    );
                                  } else if (v == 'a') {
                                    await CustodyScheduleService.setDayOverride(
                                      caseId: caseId,
                                      localDay: day,
                                      assignedParentUserId: rule.parentAUserId,
                                    );
                                  } else {
                                    await CustodyScheduleService.setDayOverride(
                                      caseId: caseId,
                                      localDay: day,
                                      assignedParentUserId: rule.parentBUserId,
                                    );
                                  }
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Custody preference saved'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Could not save: $e')),
                                  );
                                }
                              },
                  ),
                ],
              ),
            );
              },
            );
          },
        );
      },
    );
  }
}

class _DayActionPanel extends StatelessWidget {
  const _DayActionPanel({
    required this.caseId,
    required this.selectedDate,
  });

  final String caseId;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final workflowLocked =
        !session.isAttorney && !session.unlockedParentPremiumFeatures;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PLDesign.border),
        boxShadow: PLDesign.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Actions',
            style: PLDesign.caption.copyWith(
              color: PLDesign.textMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          _ActionButton(
            icon: Icons.swap_horiz_rounded,
            label: 'Propose exchange',
            onTap: () {
              if (workflowLocked) {
                showPremiumUpgradeSheet(
                  context,
                  feature: DashboardPremiumFeature.proposals,
                );
                return;
              }
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CreateProposalScreen(
                    initialDate: selectedDate,
                    initialKind: ProposalType.schedule,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.payments_outlined,
            label: 'Add expense',
            onTap: () {
              if (workflowLocked) {
                showPremiumUpgradeSheet(
                  context,
                  feature: DashboardPremiumFeature.expenseLedger,
                );
                return;
              }
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CreateProposalScreen(
                    initialDate: selectedDate,
                    initialKind: ProposalType.expense,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Send message',
            onTap: () {
              final draft =
                  'Regarding ${DateFormat.yMMMd().format(selectedDate)}:\n\n';
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ConversationThreadScreen(
                    title: context.tTone('messages'),
                    caseId: caseId,
                    conversationId: CaseMessagingService.defaultConversationId,
                    initialComposerText: draft,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.cloud_upload_outlined,
            label: 'Upload document',
            onTap: () {
              if (workflowLocked) {
                showPremiumUpgradeSheet(
                  context,
                  feature: DashboardPremiumFeature.documentsLibrary,
                );
                return;
              }
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DocumentsLibraryScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          foregroundColor: PLDesign.textPrimary,
          backgroundColor: PLDesign.surface,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: PLDesign.border.withValues(alpha: 0.9)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: PLDesign.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: PLDesign.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: PLDesign.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Timeline rows for [selectedDate], newest-at-bottom sort within the day.
class DayTimelineList extends StatelessWidget {
  const DayTimelineList({
    super.key,
    required this.caseId,
    required this.selectedDate,
    required this.sameDay,
  });

  final String caseId;
  final DateTime selectedDate;
  final bool Function(CaseEvent e, DateTime day) sameDay;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CaseEvent>>(
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
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data ?? [];
        final dayEvents = all
            .where((e) => sameDay(e, selectedDate))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        if (dayEvents.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 48,
                  color: PLDesign.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'No activity recorded for this day',
                  style: PLDesign.sectionTitle.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Use the actions above to log events or proposals.',
                  style: PLDesign.caption.copyWith(height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final uids = <String>{};
        for (final e in dayEvents) {
          if (e.actorId.isNotEmpty) uids.add(e.actorId);
        }

        return FutureBuilder<Map<String, TimelineActor>>(
          future: TimelineActor.loadMany(uids),
          builder: (context, actorSnap) {
            if (actorSnap.connectionState == ConnectionState.waiting &&
                !actorSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final actors = actorSnap.data ?? {};
            final timeFmt = DateFormat.jm();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              itemCount: dayEvents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final ev = dayEvents[i];
                final actor = actors[ev.actorId];
                final fromLine = actor != null
                    ? '${actor.fullName} (${actor.roleLabel})'
                    : (ev.actorName.isNotEmpty
                        ? ev.actorName
                        : 'Participant');
                return _DayAuditCard(
                  event: ev,
                  timeLabel: timeFmt.format(ev.createdAt.toLocal()),
                  fromLine: fromLine,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _DayAuditCard extends StatelessWidget {
  const _DayAuditCard({
    required this.event,
    required this.timeLabel,
    required this.fromLine,
  });

  final CaseEvent event;
  final String timeLabel;
  final String fromLine;

  IconData _categoryIcon() {
    if (event.isMessageLike) return Icons.chat_bubble_outline_rounded;
    if (event.isExpenseLike) return Icons.receipt_long_rounded;
    if (event.isScheduleLike) return Icons.swap_horiz_rounded;
    if (event.type == CaseEventTypes.statusChange) {
      return Icons.flag_outlined;
    }
    return Icons.article_outlined;
  }

  String _categoryLabel() {
    if (event.isMessageLike) return 'Message';
    if (event.isExpenseLike) return 'Expense';
    if (event.isScheduleLike) return 'Exchange';
    if (event.type == CaseEventTypes.statusChange) return 'Status';
    return 'Record';
  }

  @override
  Widget build(BuildContext context) {
    final border = PLDesign.border.withValues(alpha: 0.85);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: PLDesign.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_categoryIcon(), size: 18, color: PLDesign.primary),
              const SizedBox(width: 8),
              Text(
                _categoryLabel(),
                style: PLDesign.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: PLDesign.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                timeLabel,
                style: PLDesign.caption.copyWith(
                  color: PLDesign.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.title.isNotEmpty ? event.title : event.type,
            style: PLDesign.sectionTitle.copyWith(fontSize: 16, height: 1.25),
          ),
          const SizedBox(height: 10),
          Text(
            'From: $fromLine',
            style: PLDesign.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              event.description,
              style: PLDesign.body.copyWith(height: 1.4, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
