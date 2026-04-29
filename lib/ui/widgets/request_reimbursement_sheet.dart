import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/design.dart';
import '../../services/case_expense_service.dart';

/// Premium bottom sheet: log a reimbursement request as an unpaid case expense.
Future<void> showRequestReimbursementSheet(
  BuildContext context, {
  required String caseId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => RequestReimbursementSheet(caseId: caseId),
  );
}

class RequestReimbursementSheet extends StatefulWidget {
  const RequestReimbursementSheet({super.key, required this.caseId});

  final String caseId;

  @override
  State<RequestReimbursementSheet> createState() =>
      _RequestReimbursementSheetState();
}

class _RequestReimbursementSheetState extends State<RequestReimbursementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    final s = raw.trim().replaceAll(r'$', '').replaceAll(',', '').trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount greater than 0')),
        );
      }
      return;
    }

    final description = _descriptionCtrl.text.trim();
    if (description.isEmpty) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);

    setState(() => _submitting = true);
    try {
      await CaseExpenseService.addExpense(
        caseId: widget.caseId,
        amount: amount,
        description: description,
        paid: false,
      );
      if (!mounted) return;
      nav.pop();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Request submitted')),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[RequestReimbursementSheet] submit failed: $e');
        debugPrint('$st');
      }
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            kDebugMode
                ? 'Could not submit: $e'
                : 'Could not submit request. Try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = (MediaQuery.sizeOf(context).height * 0.58)
        .clamp(340.0, 560.0);
    final route = ModalRoute.of(context);
    final anim = route?.animation ?? const AlwaysStoppedAnimation<double>(1);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                height: sheetHeight,
                child: Container(
                  decoration: const BoxDecoration(
                    color: PLDesign.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(
                      top: BorderSide(color: PLDesign.border),
                      left: BorderSide(color: PLDesign.border),
                      right: BorderSide(color: PLDesign.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: PLDesign.textMuted.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Request Reimbursement',
                                style: PLDesign.sectionTitle.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.close_rounded,
                                color: PLDesign.textMuted
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Amount',
                                  style: PLDesign.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: PLDesign.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _amountCtrl,
                                  enabled: !_submitting,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: false,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]')),
                                  ],
                                  style: PLDesign.body.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    prefixText: r'$ ',
                                    prefixStyle: PLDesign.body.copyWith(
                                      color: PLDesign.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    filled: true,
                                    fillColor: PLDesign.card,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: PLDesign.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: PLDesign.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: PLDesign.primary
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  validator: (v) {
                                    final n = _parseAmount(v ?? '');
                                    if (n == null || n <= 0) {
                                      return 'Enter an amount greater than 0';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Description',
                                  style: PLDesign.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: PLDesign.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _descriptionCtrl,
                                  enabled: !_submitting,
                                  minLines: 2,
                                  maxLines: 4,
                                  style: PLDesign.body,
                                  decoration: InputDecoration(
                                    hintText:
                                        'What is this reimbursement for?',
                                    hintStyle: PLDesign.body.copyWith(
                                      color: PLDesign.textMuted
                                          .withValues(alpha: 0.65),
                                    ),
                                    filled: true,
                                    fillColor: PLDesign.card,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: PLDesign.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: PLDesign.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: PLDesign.primary
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Description is required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: _submitting ? null : _submit,
                              borderRadius: BorderRadius.circular(16),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: _submitting
                                      ? null
                                      : const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xff4f8dff),
                                            Color(0xff2f6ce5),
                                          ],
                                        ),
                                  color: _submitting
                                      ? PLDesign.border.withValues(alpha: 0.5)
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: _submitting
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Submit Request',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
