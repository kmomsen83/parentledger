import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../providers/case_context.dart';
import '../widgets/premium_upgrade_sheet.dart';
import '../../models/custody_schedule_rule.dart';
import '../../services/custody_schedule_generator.dart';
import '../../services/custody_schedule_service.dart';
import '../../services/firestore_fields.dart';
import '../../services/timeline_actor_resolver.dart';

Future<void> showSetCustodyScheduleSheet(
  BuildContext context, {
  required String caseId,
}) {
  final session = context.read<CaseContext>();
  if (!session.isAttorney && !session.unlockedParentPremiumFeatures) {
    return showPremiumUpgradeSheet(
      context,
      feature: DashboardPremiumFeature.calendarScheduling,
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: PLDesign.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SetCustodyScheduleSheet(caseId: caseId),
  );
}

class SetCustodyScheduleSheet extends StatefulWidget {
  const SetCustodyScheduleSheet({super.key, required this.caseId});

  final String caseId;

  @override
  State<SetCustodyScheduleSheet> createState() =>
      _SetCustodyScheduleSheetState();
}

class _SetCustodyScheduleSheetState extends State<SetCustodyScheduleSheet> {
  String _type = CustodyScheduleRule.weekly;
  DateTime _startDate = DateTime.now();
  String _parentA = '';
  String _parentB = '';
  final Set<int> _weekdaysParentA = {};
  bool _parentAFirstWeekend = true;
  bool _parentAStarts2255 = true;
  List<String> _custom14 =
      CustodyScheduleGenerator.preset2255CycleTags(parentAStartsCycle: true);

  bool _saving = false;

  /// Members for [widget.caseId] from Firestore (must match validation + dropdowns).
  List<String> _memberIdsForCase = const [];

  bool _bootstrapDone = false;
  String? _bootstrapError;

  /// Resolved display names for member UIDs (from `users/{uid}`).
  Map<String, String> _uidToDisplayName = {};

  static const _typeLabels = <String, String>{
    CustodyScheduleRule.weekly: 'Weekly (pick days)',
    CustodyScheduleRule.biweekly: 'Bi-weekly (flip weeks)',
    CustodyScheduleRule.everyOtherWeekend: 'Every other weekend',
    CustodyScheduleRule.twoTwoFiveFive: '2-2-5-5 preset',
    CustodyScheduleRule.custom: 'Custom 14-day cycle',
  };

  static const _weekdayMeta = <({int n, String short})>[
    (n: DateTime.monday, short: 'Mo'),
    (n: DateTime.tuesday, short: 'Tu'),
    (n: DateTime.wednesday, short: 'We'),
    (n: DateTime.thursday, short: 'Th'),
    (n: DateTime.friday, short: 'Fr'),
    (n: DateTime.saturday, short: 'Sa'),
    (n: DateTime.sunday, short: 'Su'),
  ];

  @override
  void initState() {
    super.initState();
    _weekdaysParentA.addAll({DateTime.monday, DateTime.wednesday, DateTime.friday});

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  bool get _iAmParentA {
    final m = _myUid;
    return m != null && m.isNotEmpty && m == _parentA;
  }

  String _displayNameFor(String uid) {
    if (uid.isEmpty) return '—';
    final n = _uidToDisplayName[uid]?.trim();
    if (n != null && n.isNotEmpty) return n;
    return uid.length > 8 ? '${uid.substring(0, 6)}…' : uid;
  }

  Set<String> get _allowedMemberUids => <String>{
        ..._memberIdsForCase,
        if (_parentA.isNotEmpty) _parentA,
        if (_parentB.isNotEmpty) _parentB,
        if (_myUid != null) _myUid!,
      }..removeWhere((e) => e.isEmpty);

  bool _weekdayChipSelected(int day) {
    if (_type == CustodyScheduleRule.biweekly) {
      return _weekdaysParentA.contains(day);
    }
    if (_iAmParentA) return _weekdaysParentA.contains(day);
    return !_weekdaysParentA.contains(day);
  }

  void _toggleWeekdayChip(int day) {
    setState(() {
      if (_weekdaysParentA.contains(day)) {
        _weekdaysParentA.remove(day);
      } else {
        _weekdaysParentA.add(day);
      }
    });
  }

  Future<void> _bootstrap() async {
    try {
      final rule = await CustodyScheduleService.fetchActiveRule(widget.caseId);
      if (!mounted) return;

      DocumentSnapshot<Map<String, dynamic>>? caseSnap;
      try {
        caseSnap = await FirebaseFirestore.instance
            .collection('cases')
            .doc(widget.caseId)
            .get();
      } catch (e, st) {
        debugPrint('SetCustodyScheduleSheet case doc read: $e\n$st');
        caseSnap = null;
      }

      var members = <String>[];
      if (caseSnap?.exists == true && caseSnap!.data() != null) {
        members = FirestoreFields.readCaseMemberIds(caseSnap.data()!);
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && !members.contains(uid)) {
        members = [uid, ...members];
      }
      if (members.isEmpty && rule.isConfigured) {
        if (rule.parentAUserId.isNotEmpty) {
          members.add(rule.parentAUserId);
        }
        if (rule.parentBUserId.isNotEmpty &&
            rule.parentBUserId != rule.parentAUserId) {
          members.add(rule.parentBUserId);
        }
      }

      final nameIds = <String>{
        ...members,
        if (rule.parentAUserId.isNotEmpty) rule.parentAUserId,
        if (rule.parentBUserId.isNotEmpty) rule.parentBUserId,
        if (uid != null) uid,
      };
      final actors = await TimelineActor.loadMany(nameIds);
      final names = <String, String>{
        for (final e in actors.entries) e.key: e.value.fullName,
      };

      setState(() {
        _memberIdsForCase = List<String>.from(members);
        _uidToDisplayName = names;
        _bootstrapDone = true;
        _bootstrapError = null;

        if (rule.isConfigured) {
          _type = rule.type;
          _startDate = rule.startDate;
          _parentA = rule.parentAUserId;
          _parentB = rule.parentBUserId;
          _weekdaysParentA
            ..clear()
            ..addAll(rule.weeklyDaysParentA);
          _parentAFirstWeekend = rule.parentAFirstWeekend;
          _parentAStarts2255 = rule.parentAStarts2255Cycle;
          if (rule.customCycle14 != null && rule.customCycle14!.length == 14) {
            _custom14 = List<String>.from(rule.customCycle14!);
          }
        } else if (uid != null && members.where((id) => id != uid).isNotEmpty) {
          _parentA = uid;
          _parentB = members.firstWhere((id) => id != uid);
        } else if (members.length >= 2) {
          _parentA = members[0];
          _parentB = members[1];
        } else if (members.isNotEmpty) {
          _parentA = members.first;
          _parentB = members.first;
        }
      });
    } catch (e, st) {
      debugPrint('SetCustodyScheduleSheet bootstrap failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _bootstrapDone = true;
        _bootstrapError = e.toString();
      });
    }
  }

  Future<void> _pickStartDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2040),
    );
    if (d != null) setState(() => _startDate = d);
  }

  void _apply2255Preset() {
    setState(() {
      _type = CustodyScheduleRule.twoTwoFiveFive;
      _custom14 = CustodyScheduleGenerator.preset2255CycleTags(
        parentAStartsCycle: _parentAStarts2255,
      );
    });
  }

  void _cycleCustomDay(int index) {
    setState(() {
      final v = _custom14[index] == 'a' ? 'b' : 'a';
      _custom14 = List<String>.from(_custom14)..[index] = v;
    });
  }

  Future<void> _save() async {
    final session = context.read<CaseContext>();
    if (session.isAttorney) {
      _toast('Only parent accounts can save a custody schedule.');
      return;
    }

    final allowed = _allowedMemberUids;
    if (_parentA.isEmpty || _parentB.isEmpty || _parentA == _parentB) {
      _toast('Choose two different parents from the case.');
      return;
    }
    if (!allowed.contains(_parentA) || !allowed.contains(_parentB)) {
      _toast(
        'Could not verify both parents on this case. Pull to refresh your dashboard '
        'and try again, or ask support if membership looks wrong.',
      );
      return;
    }

    if (_type != CustodyScheduleRule.twoTwoFiveFive &&
        _type != CustodyScheduleRule.custom) {
      if (_weekdaysParentA.isEmpty) {
        _toast(
          'Select at least one weekday for ${_displayNameFor(_parentA)} '
          '(custody pattern slot A).',
        );
        return;
      }
    }

    if (_type == CustodyScheduleRule.custom) {
      if (_custom14.length != 14) {
        _toast('Custom cycle must be 14 days.');
        return;
      }
    }

    final rule = CustodyScheduleRule(
      type: _type,
      startDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
      parentAUserId: _parentA,
      parentBUserId: _parentB,
      weeklyDaysParentA: _weekdaysParentA.toList()..sort(),
      customCycle14: _type == CustodyScheduleRule.custom ||
              _type == CustodyScheduleRule.twoTwoFiveFive
          ? List<String>.from(_custom14)
          : null,
      parentAFirstWeekend: _parentAFirstWeekend,
      parentAStarts2255Cycle: _parentAStarts2255,
    );

    setState(() => _saving = true);
    try {
      await CustodyScheduleService.saveRule(
        caseId: widget.caseId,
        rule: rule,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custody schedule saved')),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final session = context.read<CaseContext>();
    if (session.isAttorney) {
      _toast('Only parent accounts can change the custody schedule.');
      return;
    }

    setState(() => _saving = true);
    try {
      await CustodyScheduleService.clearRule(widget.caseId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custody schedule cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Could not clear: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _weekdaySectionCaption() {
    switch (_type) {
      case CustodyScheduleRule.everyOtherWeekend:
        return 'Weekdays (Mon–Fri): ${_displayNameFor(_parentA)} on selected days';
      default:
        return '${_displayNameFor(_parentA)} has custody on:';
    }
  }

  String _weekdaySectionHint() {
    final me = _myUid;
    if (me == null || _type == CustodyScheduleRule.biweekly) return '';
    if (_parentA == me) {
      return 'Selected days are yours (${_displayNameFor(me)}).';
    }
    if (_parentB == me) {
      return 'Tap the days you (${_displayNameFor(me)}) have — '
          '${_displayNameFor(_parentA)} gets the other weekdays.';
    }
    return '';
  }

  String _shortInitial(String uid) {
    final n = _displayNameFor(uid).trim();
    if (n.isEmpty || n == '—') return '?';
    return n.substring(0, 1).toUpperCase();
  }

  Widget _identityTile({required String title, String? subtitle}) {
    return Container(
      decoration: BoxDecoration(
        color: PLDesign.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PLDesign.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: PLDesign.body.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle, style: PLDesign.caption),
              ),
          ],
        ),
      ),
    );
  }

  Widget _parentIdentitySection({
    required List<String> memberIds,
    required bool readOnly,
  }) {
    final me = _myUid ?? '';
    final onSchedule =
        me.isNotEmpty && (me == _parentA || me == _parentB);

    if (_parentA.isEmpty || _parentB.isEmpty || _parentA == _parentB) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Both parents must be on this case to set a schedule.',
          style: PLDesign.caption.copyWith(color: PLDesign.danger),
        ),
      );
    }

    if (onSchedule) {
      final coparentUid = me == _parentA ? _parentB : _parentA;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _identityTile(
            title: 'You — ${_displayNameFor(me)}',
            subtitle: 'On this phone',
          ),
          const SizedBox(height: 10),
          _identityTile(
            title: 'Co-parent — ${_displayNameFor(coparentUid)}',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _parentDropdown(
          label: 'Parent A (pattern slot A)',
          value: _parentA,
          memberIds: memberIds,
          readOnly: readOnly,
          onChanged: (v) => setState(() => _parentA = v ?? ''),
        ),
        const SizedBox(height: 8),
        _parentDropdown(
          label: 'Parent B (pattern slot B)',
          value: _parentB,
          memberIds: memberIds,
          readOnly: readOnly,
          onChanged: (v) => setState(() => _parentB = v ?? ''),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Your account is not listed on this saved schedule. Assign each '
            'pattern slot to the correct parent, or ask a parent to update it.',
            style: PLDesign.caption.copyWith(
              color: PLDesign.textMuted,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final memberIds = _memberIdsForCase;
    final attorneyReadOnly = session.isAttorney;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Set custody schedule',
                        style: PLDesign.sectionTitle.copyWith(fontSize: 20),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: PLDesign.textMuted,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    if (!_bootstrapDone)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_bootstrapError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: PLDesign.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Could not load this case: $_bootstrapError',
                              style: PLDesign.caption.copyWith(
                                color: PLDesign.danger,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_bootstrapDone &&
                        _bootstrapError == null &&
                        attorneyReadOnly)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: PLDesign.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Counsel can view this schedule but cannot edit it. '
                              'A parent on the case must save changes.',
                              style: PLDesign.caption.copyWith(height: 1.35),
                            ),
                          ),
                        ),
                      ),
                    if (_bootstrapDone && _bootstrapError == null) ...[
                    Text(
                      'Choose how custody repeats. The calendar fills from your start date. '
                      'You can still override single days from the day view.',
                      style: PLDesign.caption.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: _fieldDecoration('Pattern type'),
                      value: _type,
                      items: _typeLabels.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: attorneyReadOnly
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() {
                                _type = v;
                                if (v == CustodyScheduleRule.twoTwoFiveFive) {
                                  _apply2255Preset();
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Start date',
                        style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd().format(_startDate),
                        style: PLDesign.body.copyWith(
                          color: PLDesign.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(Icons.calendar_month, color: PLDesign.primary),
                      onTap: attorneyReadOnly ? null : _pickStartDate,
                    ),
                    const SizedBox(height: 8),
                    _parentIdentitySection(
                      memberIds: memberIds,
                      readOnly: attorneyReadOnly,
                    ),
                    if (_type == CustodyScheduleRule.everyOtherWeekend) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${_displayNameFor(_parentA)} has the first weekend block',
                          style: PLDesign.body,
                        ),
                        value: _parentAFirstWeekend,
                        activeThumbColor: PLDesign.primary,
                        onChanged: attorneyReadOnly
                            ? null
                            : (v) =>
                                setState(() => _parentAFirstWeekend = v),
                      ),
                    ],
                    if (_type == CustodyScheduleRule.twoTwoFiveFive) ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${_displayNameFor(_parentA)} starts the standard 2-2-5-5 phase',
                          style: PLDesign.body,
                        ),
                        subtitle: Text(
                          'Turn off to swap ${_displayNameFor(_parentA)} / ${_displayNameFor(_parentB)} for the whole 14-day block.',
                          style: PLDesign.caption,
                        ),
                        value: _parentAStarts2255,
                        activeThumbColor: PLDesign.primary,
                        onChanged: attorneyReadOnly
                            ? null
                            : (v) {
                                setState(() {
                                  _parentAStarts2255 = v;
                                  _custom14 =
                                      CustodyScheduleGenerator.preset2255CycleTags(
                                    parentAStartsCycle: v,
                                  );
                                });
                              },
                      ),
                    ],
                    if (_type == CustodyScheduleRule.weekly ||
                        _type == CustodyScheduleRule.biweekly ||
                        _type == CustodyScheduleRule.everyOtherWeekend) ...[
                      const SizedBox(height: 12),
                      Text(
                        _weekdaySectionCaption(),
                        style: PLDesign.caption.copyWith(
                          color: PLDesign.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_type != CustodyScheduleRule.biweekly)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _weekdaySectionHint(),
                            style: PLDesign.caption.copyWith(
                              color: PLDesign.textMuted,
                              height: 1.25,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _weekdayMeta.map((m) {
                          final on = _weekdayChipSelected(m.n);
                          return FilterChip(
                            label: Text(m.short),
                            selected: on,
                            onSelected: attorneyReadOnly
                                ? null
                                : (_) => _toggleWeekdayChip(m.n),
                            selectedColor:
                                PLDesign.primary.withValues(alpha: 0.35),
                            checkmarkColor: PLDesign.textPrimary,
                          );
                        }).toList(),
                      ),
                    ],
                    if (_type == CustodyScheduleRule.custom ||
                        _type == CustodyScheduleRule.twoTwoFiveFive) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '14-day cycle (tap to swap ${_shortInitial(_parentA)} / ${_shortInitial(_parentB)})',
                              style: PLDesign.caption.copyWith(
                                color: PLDesign.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_type == CustodyScheduleRule.custom)
                            TextButton(
                              onPressed: attorneyReadOnly
                                  ? null
                                  : () {
                                      setState(() {
                                        _custom14 =
                                            CustodyScheduleGenerator.preset2255CycleTags(
                                          parentAStartsCycle: true,
                                        );
                                      });
                                    },
                              child: const Text('Reset to 2-2-5-5'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _customCycleGrid(
                        readOnly: attorneyReadOnly,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: (_saving ||
                              !_bootstrapDone ||
                              attorneyReadOnly ||
                              _bootstrapError != null)
                          ? null
                          : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: PLDesign.primary,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save schedule'),
                    ),
                    TextButton(
                      onPressed: (_saving ||
                              !_bootstrapDone ||
                              attorneyReadOnly ||
                              _bootstrapError != null)
                          ? null
                          : _clear,
                      child: Text(
                        'Clear saved schedule',
                        style: TextStyle(color: PLDesign.danger),
                      ),
                    ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
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
    );
  }

  Widget _parentDropdown({
    required String label,
    required String value,
    required List<String> memberIds,
    required bool readOnly,
    required ValueChanged<String?> onChanged,
  }) {
    final ids = memberIds.isEmpty
        ? <String>[if (value.isNotEmpty) value]
        : memberIds;
    return DropdownButtonFormField<String>(
      decoration: _fieldDecoration(label),
      value: value.isEmpty || !ids.contains(value) ? null : value,
      hint: const Text('Select'),
      items: ids
          .map(
            (id) => DropdownMenuItem(
              value: id,
              child: Text(
                _displayNameFor(id),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: readOnly ? null : onChanged,
    );
  }

  Widget _customCycleGrid({required bool readOnly}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.1,
      ),
      itemCount: 14,
      itemBuilder: (context, i) {
        final isA = _custom14[i] == 'a';
        return Material(
          color: isA
              ? PLDesign.primary.withValues(alpha: 0.25)
              : PLDesign.success.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: readOnly ? null : () => _cycleCustomDay(i),
            borderRadius: BorderRadius.circular(10),
            child: Center(
              child: Text(
                '${i + 1}\n${isA ? _shortInitial(_parentA) : _shortInitial(_parentB)}',
                textAlign: TextAlign.center,
                style: PLDesign.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
