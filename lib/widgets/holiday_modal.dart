import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../models/custody_schedule_rule.dart';
import '../models/holiday.dart';
import '../providers/case_context.dart';
import '../services/case_messaging_service.dart';
import '../services/holiday_service.dart';
import '../providers/holiday_provider.dart' show holidayEmojiForName;
import '../ui/conversation_thread_screen.dart';

/// Detail sheet for a holiday custody day + proposal flows.
Future<void> showHolidayDetailSheet({
  required BuildContext context,
  required String caseId,
  required Holiday holiday,
  required CustodyScheduleRule rule,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _HolidayDetailBody(
      caseId: caseId,
      holiday: holiday,
      rule: rule,
      currentUid: uid,
    ),
  );
}

Future<void> showCreateHolidayDialog({
  required BuildContext context,
  required String caseId,
  required CustodyScheduleRule rule,
  DateTime? initialDate,
}) async {
  if (!rule.isConfigured) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Set custody schedule first (parent A/B).')),
    );
    return;
  }

  final nameCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  var picked = initialDate ??
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  var assignUid = rule.parentAUserId;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Add holiday'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Holiday name',
                      hintText: 'e.g. Christmas Day',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(
                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: picked,
                        firstDate: DateTime(picked.year - 2),
                        lastDate: DateTime(picked.year + 3),
                      );
                      if (d != null) setLocal(() => picked = d);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(assignUid),
                    decoration: const InputDecoration(labelText: 'Assigned parent'),
                    initialValue: assignUid,
                    items: [
                      DropdownMenuItem(
                        value: rule.parentAUserId,
                        child: const Text('Parent A'),
                      ),
                      DropdownMenuItem(
                        value: rule.parentBUserId,
                        child: const Text('Parent B'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => assignUid = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  try {
                    await HolidayService.createHoliday(
                      Holiday(
                        id: '',
                        caseId: caseId,
                        name: name,
                        dateLocal: picked,
                        assignedParentId: assignUid,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                        isOverride: true,
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Holiday saved')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not save: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _HolidayDetailBody extends StatelessWidget {
  const _HolidayDetailBody({
    required this.caseId,
    required this.holiday,
    required this.rule,
    required this.currentUid,
  });

  final String caseId;
  final Holiday holiday;
  final CustodyScheduleRule rule;
  final String? currentUid;

  String _parentLabel(String uid) {
    if (uid == rule.parentAUserId) return 'Parent A';
    if (uid == rule.parentBUserId) return 'Parent B';
    return 'Assigned parent';
  }

  Color _parentColor(String uid) {
    if (uid == rule.parentAUserId) return PLDesign.primary;
    if (uid == rule.parentBUserId) return PLDesign.ai;
    return PLDesign.textMuted;
  }

  String? _otherParentUid(String assigned) {
    if (assigned == rule.parentAUserId) return rule.parentBUserId;
    if (assigned == rule.parentBUserId) return rule.parentAUserId;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final coparent = context.read<CaseContext>().coparentId;

    return Container(
      decoration: BoxDecoration(
        color: PLDesign.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PLDesign.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  holidayEmojiForName(holiday.name),
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    holiday.name,
                    style: PLDesign.sectionTitle.copyWith(fontSize: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Holiday.dateKeyFor(holiday.dateLocal),
              style: PLDesign.body.copyWith(color: PLDesign.textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _parentColor(holiday.assignedParentId).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _parentColor(holiday.assignedParentId).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_rounded, color: _parentColor(holiday.assignedParentId)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _parentLabel(holiday.assignedParentId),
                      style: PLDesign.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            if (holiday.notes != null && holiday.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Notes', style: PLDesign.caption.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(holiday.notes!, style: PLDesign.body.copyWith(height: 1.4)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: rule.isConfigured && currentUid != null
                  ? () => _openSwap(context, coparent)
                  : null,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Swap holiday (propose)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: rule.isConfigured && currentUid != null
                  ? () => _openTimeChange(context, coparent)
                  : null,
              icon: const Icon(Icons.schedule_rounded),
              label: const Text('Propose time change'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openMessage(context),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: Text(context.tTone('messages')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSwap(BuildContext context, String? coparent) async {
    final other = _otherParentUid(holiday.assignedParentId);
    if (other == null || other.isEmpty) return;
    final target = coparent != null && coparent.isNotEmpty ? coparent : other;
    final msgCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Propose custody swap'),
          content: TextField(
            controller: msgCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Message to co-parent',
              hintText: 'Request to change who has this holiday…',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
                try {
                  await HolidayService.createHolidayProposal(
                    caseId: caseId,
                    holidayId: holiday.id,
                    proposedBy: uid,
                    targetParentId: target,
                    newParentId: other,
                    message: msgCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Proposal sent')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Send proposal'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTimeChange(BuildContext context, String? coparent) async {
    final other = _otherParentUid(holiday.assignedParentId);
    if (other == null) return;
    final target = coparent != null && coparent.isNotEmpty ? coparent : other;
    final msgCtrl = TextEditingController();
    TimeOfDay? startT;
    TimeOfDay? endT;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Propose time window'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      startT == null ? 'Start time (optional)' : startT!.format(ctx),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: startT ?? TimeOfDay.now(),
                      );
                      if (t != null) setLocal(() => startT = t);
                    },
                  ),
                  ListTile(
                    title: Text(
                      endT == null ? 'End time (optional)' : endT!.format(ctx),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: endT ?? TimeOfDay.now(),
                      );
                      if (t != null) setLocal(() => endT = t);
                    },
                  ),
                  TextField(
                    controller: msgCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Message'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    final base = DateTime(
                      holiday.dateLocal.year,
                      holiday.dateLocal.month,
                      holiday.dateLocal.day,
                    );
                    DateTime? st;
                    DateTime? en;
                    if (startT != null) {
                      st = base.add(Duration(
                        hours: startT!.hour,
                        minutes: startT!.minute,
                      ));
                    }
                    if (endT != null) {
                      en = base.add(Duration(
                        hours: endT!.hour,
                        minutes: endT!.minute,
                      ));
                    }
                    try {
                      await HolidayService.createHolidayProposal(
                        caseId: caseId,
                        holidayId: holiday.id,
                        proposedBy: uid,
                        targetParentId: target,
                        newParentId: holiday.assignedParentId,
                        message: msgCtrl.text.trim(),
                        startTime: st,
                        endTime: en,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Time proposal sent')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openMessage(BuildContext context) {
    final draft =
        'Regarding holiday "${holiday.name}" (${Holiday.dateKeyFor(holiday.dateLocal)}): ';
    final title = context.tTone('messages');
    Navigator.pop(context);
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ConversationThreadScreen(
          title: title,
          caseId: caseId,
          conversationId: CaseMessagingService.defaultConversationId,
          initialComposerText: draft,
        ),
      ),
    );
  }
}
