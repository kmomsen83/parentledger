import 'dart:io';

import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/case_expense_service.dart';
import '../services/expense_receipt_upload_service.dart';
import 'widgets/trust_elements.dart';
import 'widgets/premium_upgrade_sheet.dart';

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
  File? _selectedReceipt;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    if (!mounted) return;
    if (x == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image selection canceled')),
      );
      return;
    }
    setState(() => _selectedReceipt = File(x.path));
  }

  Future<void> _pickFromGallery() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (!mounted) return;
    if (x == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image selection canceled')),
      );
      return;
    }
    setState(() => _selectedReceipt = File(x.path));
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
      await showPremiumUpgradeSheet(
        context,
        feature: DashboardPremiumFeature.expenseLedger,
      );
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
      final expenseId = await CaseExpenseService.addExpense(
        caseId: caseId,
        amount: amount,
        description: combinedDescription,
        paid: _markAsPaid,
      );

      if (_selectedReceipt != null) {
        final url = await ExpenseReceiptUploadService.uploadReceipt(
          file: _selectedReceipt!,
          caseId: caseId,
          expenseId: expenseId,
        );
        if (!mounted) return;
        if (url == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload receipt')),
          );
        } else {
          await CaseExpenseService.setReceiptUrl(
            caseId: caseId,
            expenseId: expenseId,
            receiptUrl: url,
          );
        }
      }

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
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Receipt (optional)',
                    style: PLDesign.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: PLDesign.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _pickFromCamera,
                        icon: const Icon(Icons.photo_camera_outlined, size: 20),
                        label: const Text('Take Photo'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 20),
                        label: const Text('Upload from Library'),
                      ),
                    ),
                  ],
                ),
                if (_selectedReceipt != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedReceipt!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _selectedReceipt = null),
                        child: Text(
                          'Remove',
                          style: TextStyle(color: PLDesign.danger),
                        ),
                      ),
                    ],
                  ),
                ],
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
