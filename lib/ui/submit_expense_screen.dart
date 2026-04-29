import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/case_expense_service.dart';
import 'widgets/trust_elements.dart';
import 'widgets/upgrade_unlock_modal.dart';

class SubmitExpenseScreen extends StatefulWidget {
  const SubmitExpenseScreen({super.key});

  @override
  State<SubmitExpenseScreen> createState() => _SubmitExpenseScreenState();
}

class _SubmitExpenseScreenState extends State<SubmitExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _merchantController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  bool _markAsPaid = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final session = context.read<CaseContext>();
    final caseId = session.caseId;
    if (caseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('noActiveCaseFound'))),
      );
      return;
    }

    final ok = await CaseExpenseService.canAddExpense(
      caseId,
      hasFullSubscriptionAccess: session.hasFullAccess,
    );
    if (!ok) {
      if (!mounted) return;
      await showUpgradeToUnlockModal(context);
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final description = _descriptionController.text.trim();
    final merchant = _merchantController.text.trim();
    final notes = _notesController.text.trim();
    final combinedDescription = [
      description,
      if (merchant.isNotEmpty) 'Merchant: $merchant',
      if (notes.isNotEmpty) 'Notes: $notes',
    ].join(' | ');

    setState(() => _isSubmitting = true);
    try {
      await CaseExpenseService.addExpense(
        caseId: caseId,
        amount: amount,
        description: combinedDescription,
        paid: _markAsPaid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('expenseSubmittedSuccessfully'))),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit expense: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('submitExpense')),
        backgroundColor: PLDesign.surface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create a clear, court-ready expense record.',
                  style: PLDesign.caption.copyWith(height: 1.4),
                ),
                const SizedBox(height: 10),
                const TrustNote(
                  text:
                      'Expenses are tracked with timestamps and full history for transparency.',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount (USD)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    final amount = double.tryParse(text);
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Expense type',
                    hintText: 'Example: School supplies',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Expense type is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _merchantController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant or provider (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Add context for reimbursement review.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tTone('markAsAlreadyPaid')),
                  subtitle: const Text(
                    'Status changes are recorded for your case history.',
                  ),
                  value: _markAsPaid,
                  onChanged: (value) => setState(() => _markAsPaid = value),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tTone('submitExpense')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
