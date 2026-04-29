import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../providers/case_context.dart';
import '../../services/custody_risk_insights_service.dart';
import '../../services/proposal_service.dart';

/// Proposal category for [CreateProposalScreen] (calendar pre-fill, segmented control).
enum ProposalType { schedule, expense, location }

/// Creates negotiation proposals in top-level `proposals/` with ledger-backed audit.
class CreateProposalScreen extends StatefulWidget {
  const CreateProposalScreen({
    super.key,
    /// Pre-filled calendar date (local day); used from calendar / day detail.
    this.initialDate,
    /// Opens with schedule, expense, or location selected.
    this.initialKind,
  });

  final DateTime? initialDate;
  final ProposalType? initialKind;

  @override
  State<CreateProposalScreen> createState() => _CreateProposalScreenState();
}

class _CreateProposalScreenState extends State<CreateProposalScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<TimeOfDay>> _timeFieldKey =
      GlobalKey<FormFieldState<TimeOfDay>>();

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  ProposalType _kind = ProposalType.schedule;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _submitting = false;

  static const int _maxNotes = 500;

  @override
  void initState() {
    super.initState();
    final id = widget.initialDate;
    if (id != null) {
      _selectedDate = DateTime(id.year, id.month, id.day);
    }
    final ik = widget.initialKind;
    if (ik != null) {
      _kind = ik;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasCase =>
      (context.read<CaseContext>().caseId ?? '').trim().isNotEmpty;

  String get _notesTrimmed => _notesController.text.trim();

  String? _validateNotes(String? _) {
    if (_notesTrimmed.length > _maxNotes) {
      return 'Notes must be $_maxNotes characters or fewer';
    }
    return null;
  }

  DateTime? _scheduledAt() {
    final d = _selectedDate;
    final t = _selectedTime;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  bool _formComplete() {
    if (!_hasCase) return false;
    switch (_kind) {
      case ProposalType.schedule:
        final loc = _locationController.text.trim();
        return _selectedDate != null &&
            _selectedTime != null &&
            loc.isNotEmpty &&
            _notesTrimmed.length <= _maxNotes;
      case ProposalType.expense:
        final amt = double.tryParse(_amountController.text.trim());
        return _selectedDate != null &&
            amt != null &&
            amt > 0 &&
            _notesTrimmed.length <= _maxNotes;
      case ProposalType.location:
        final loc = _locationController.text.trim();
        return _selectedDate != null &&
            loc.isNotEmpty &&
            _notesTrimmed.length <= _maxNotes;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: PLDesign.primary,
            surface: PLDesign.surface,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 17, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: PLDesign.primary,
            surface: PLDesign.surface,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (t != null) {
      setState(() => _selectedTime = t);
      _timeFieldKey.currentState?.didChange(t);
    }
  }

  Future<({String id, String name})?> _primaryChild(String caseId) async {
    final snap = await FirebaseFirestore.instance
        .collection('cases')
        .doc(caseId)
        .collection('children')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final m = doc.data();
    final fn = (m['firstName'] ?? '').toString().trim();
    final ln = (m['lastName'] ?? '').toString().trim();
    final nm = (m['name'] ?? '').toString().trim();
    final label = nm.isNotEmpty
        ? nm
        : ('$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : 'Child');
    return (id: doc.id, name: label);
  }

  Future<Map<String, dynamic>> _priorExchangeTerms(String caseId) async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('cases')
          .doc(caseId)
          .collection('exchanges')
          .orderBy('scheduledTime', descending: true)
          .limit(1)
          .get();
      if (q.docs.isEmpty) {
        return <String, dynamic>{
          'detail': 'No custody exchange on record before this proposal.',
        };
      }
      final m = q.docs.first.data();
      final ts = m['scheduledTime'];
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      final loc = (m['locationName'] ?? m['address'] ?? '').toString().trim();
      return <String, dynamic>{
        if (dt != null) 'scheduledTime': dt.toIso8601String(),
        if (loc.isNotEmpty) 'locationName': loc,
        if (m['notes'] != null &&
            m['notes'].toString().trim().isNotEmpty)
          'notes': m['notes'].toString(),
      };
    } catch (_) {
      return <String, dynamic>{
        'detail': 'Prior exchange history could not be loaded.',
      };
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final caseId = context.read<CaseContext>().caseId?.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (caseId == null || caseId.isEmpty || uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in and open a case to submit.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Choose a date.')),
      );
      return;
    }

    if (_kind == ProposalType.schedule) {
      if (_selectedTime == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Choose a time for the schedule.'),
          ),
        );
        return;
      }
      if (_locationController.text.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Location is required.')),
        );
        return;
      }
    }
    if (_kind == ProposalType.expense) {
      final amt = double.tryParse(_amountController.text.trim());
      if (amt == null || amt <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Enter an amount greater than zero.')),
        );
        return;
      }
    }
    if (_kind == ProposalType.location &&
        _locationController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Location is required.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final notes = _notesTrimmed.isEmpty ? '' : _notesTrimmed;
      final dateOnly = _selectedDate!;

      final child = await _primaryChild(caseId);
      if (child == null) {
        throw StateError(
          'Add a child profile before creating a proposal.',
        );
      }

      switch (_kind) {
        case ProposalType.schedule:
          final scheduledAt = _scheduledAt()!;
          final location = _locationController.text.trim();
          final original = await _priorExchangeTerms(caseId);
          final proposed = <String, dynamic>{
            'scheduledTime': scheduledAt.toIso8601String(),
            'locationName': location,
            'exchangeType': 'proposed',
            if (notes.isNotEmpty) 'notes': notes,
          };
          final title =
              'Schedule change · ${DateFormat.yMMMd().add_jm().format(scheduledAt)}';
          final summary = StringBuffer()
            ..writeln(title)
            ..writeln('Location: $location')
            ..writeln('Child: ${child.name}');
          if (notes.isNotEmpty) summary.writeln('Notes: $notes');
          await ProposalService.createScheduleProposal(
            caseId: caseId,
            childId: child.id,
            childName: child.name,
            title: title,
            originalData: original,
            proposedData: proposed,
            summary: summary.toString().trim(),
          );
          break;

        case ProposalType.expense:
          final amount = double.parse(_amountController.text.trim());
          final title = notes.isEmpty
              ? 'Expense · \$${amount.toStringAsFixed(2)}'
              : 'Expense · ${notes.length > 48 ? '${notes.substring(0, 48)}…' : notes}';
          final proposed = <String, dynamic>{
            'amount': amount,
            'requestedDate': DateTime(
              dateOnly.year,
              dateOnly.month,
              dateOnly.day,
            ).toIso8601String(),
            if (notes.isNotEmpty) 'notes': notes,
          };
          final summary = StringBuffer()
            ..writeln(title)
            ..writeln('Amount: ${amount.toStringAsFixed(2)}')
            ..writeln('Child: ${child.name}');
          await ProposalService.createProposal(
            caseId: caseId,
            childId: child.id,
            childName: child.name,
            kind: 'expense',
            title: title,
            originalData: <String, dynamic>{
              'detail': 'This proposal does not replace a specific prior expense line item.',
            },
            proposedData: proposed,
            summary: summary.toString().trim(),
          );
          break;

        case ProposalType.location:
          final locationName = _locationController.text.trim();
          final title =
              'Location · ${locationName.length > 36 ? '${locationName.substring(0, 36)}…' : locationName}';
          final proposed = <String, dynamic>{
            'locationName': locationName,
            'requestedDate': DateTime(
              dateOnly.year,
              dateOnly.month,
              dateOnly.day,
            ).toIso8601String(),
            if (notes.isNotEmpty) 'notes': notes,
          };
          final summary = StringBuffer()
            ..writeln(title)
            ..writeln('Child: ${child.name}');
          if (notes.isNotEmpty) summary.writeln('Notes: $notes');
          await ProposalService.createProposal(
            caseId: caseId,
            childId: child.id,
            childName: child.name,
            kind: 'location',
            title: title,
            originalData: <String, dynamic>{
              'detail': 'No prior pinned location replaced by this proposal.',
            },
            proposedData: proposed,
            summary: summary.toString().trim(),
          );
          break;
      }

      await CustodyRiskInsightsService.refresh(caseId);

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Proposal submitted')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not submit: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final valid = _formComplete();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Create Proposal'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_hasCase)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No case on this account — proposals cannot be saved.',
                    style: PLDesign.body.copyWith(color: PLDesign.danger),
                  ),
                ),
              _section(
                title: 'Proposal type',
                child: SegmentedButton<ProposalType>(
                  segments: const [
                    ButtonSegment(
                      value: ProposalType.schedule,
                      label: Text('Schedule'),
                      icon: Icon(Icons.calendar_month_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: ProposalType.expense,
                      label: Text('Expense'),
                      icon: Icon(Icons.payments_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ProposalType.location,
                      label: Text('Location'),
                      icon: Icon(Icons.place_outlined, size: 18),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) {
                    setState(() {
                      _kind = s.first;
                      if (_kind != ProposalType.schedule) {
                        _selectedTime = null;
                      }
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor:
                        PLDesign.primary.withValues(alpha: 0.35),
                    foregroundColor: PLDesign.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _section(
                title: 'Date',
                child: FormField<DateTime>(
                  key: ValueKey<String>('proposal_date_${_kind.name}'),
                  initialValue: _selectedDate,
                  validator: (v) =>
                      v == null ? 'Date is required' : null,
                  builder: (state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                state.value == null
                                    ? 'Select date'
                                    : DateFormat.yMMMd()
                                        .format(state.value!),
                                style: PLDesign.body.copyWith(
                                  color: PLDesign.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await _pickDate();
                                if (_selectedDate != null) {
                                  state.didChange(_selectedDate);
                                }
                              },
                              child: const Text('Choose'),
                            ),
                          ],
                        ),
                        if (state.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              state.errorText!,
                              style: TextStyle(
                                color: PLDesign.danger,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (_kind == ProposalType.schedule) ...[
                const SizedBox(height: 14),
                _section(
                  title: 'Time',
                  child: FormField<TimeOfDay>(
                    key: _timeFieldKey,
                    initialValue: _selectedTime,
                    validator: (v) =>
                        v == null ? 'Time is required' : null,
                    builder: (state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  state.value == null
                                      ? 'Select time'
                                      : state.value!.format(context),
                                  style: PLDesign.body.copyWith(
                                    color: PLDesign.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await _pickTime();
                                  if (_selectedTime != null) {
                                    state.didChange(_selectedTime);
                                  }
                                },
                                child: const Text('Choose'),
                              ),
                            ],
                          ),
                          if (state.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                state.errorText!,
                                style: TextStyle(
                                  color: PLDesign.danger,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              if (_kind == ProposalType.schedule ||
                  _kind == ProposalType.location) ...[
                const SizedBox(height: 14),
                _section(
                  title: _kind == ProposalType.schedule
                      ? 'Location'
                      : 'Location',
                  child: TextFormField(
                    controller: _locationController,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: PLDesign.textPrimary),
                    decoration: _fieldDecoration(
                      hint: _kind == ProposalType.schedule
                          ? 'Exchange location'
                          : 'Proposed location',
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (_kind == ProposalType.schedule ||
                          _kind == ProposalType.location) {
                        if (t.isEmpty) return 'Location is required';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
              if (_kind == ProposalType.expense) ...[
                const SizedBox(height: 14),
                _section(
                  title: 'Amount',
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: PLDesign.textPrimary),
                    decoration: _fieldDecoration(hint: '0.00'),
                    validator: (v) {
                      final raw = v?.trim() ?? '';
                      if (raw.isEmpty) return 'Enter an amount';
                      final n = double.tryParse(raw);
                      if (n == null) return 'Enter a valid number';
                      if (n <= 0) return 'Amount must be greater than zero';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _section(
                title: 'Notes (optional)',
                child: TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  maxLength: _maxNotes,
                  style: const TextStyle(color: PLDesign.textPrimary),
                  decoration: _fieldDecoration(
                    hint: 'Context for your co-parent or attorney record',
                  ).copyWith(
                    counterStyle: TextStyle(color: PLDesign.textMuted),
                  ),
                  validator: _validateNotes,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed:
                      (_submitting || !valid || !_hasCase) ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: PLDesign.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: PLDesign.border,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit proposal',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PLDesign.border),
        boxShadow: PLDesign.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PLDesign.caption.copyWith(
              color: PLDesign.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: PLDesign.textMuted.withValues(alpha: 0.8)),
      filled: true,
      fillColor: PLDesign.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PLDesign.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PLDesign.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PLDesign.primary.withValues(alpha: 0.85)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PLDesign.danger.withValues(alpha: 0.9)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PLDesign.danger.withValues(alpha: 0.9)),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}
