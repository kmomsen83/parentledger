import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/case_expense_service.dart';
import 'widgets/expense_receipt_fullscreen.dart';
import 'widgets/trust_elements.dart';

class ApproveDenyExpenseScreen extends StatefulWidget {
  const ApproveDenyExpenseScreen({
    super.key,
    required this.expenseId,
  });

  final String expenseId;

  @override
  State<ApproveDenyExpenseScreen> createState() =>
      _ApproveDenyExpenseScreenState();
}

class _ApproveDenyExpenseScreenState extends State<ApproveDenyExpenseScreen> {
  bool _busy = false;

  Future<void> _setStatus({
    required String caseId,
    required bool approved,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (approved) {
        await CaseExpenseService.setPaid(
          caseId: caseId,
          expenseId: widget.expenseId,
          paid: true,
        );
      } else {
        await CaseExpenseService.setStatus(
          caseId: caseId,
          expenseId: widget.expenseId,
          status: 'denied',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Expense approved.' : 'Expense denied.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update expense: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId;
    if (caseId == null) {
      return Scaffold(
        backgroundColor: PLDesign.background,
        appBar: AppBar(title: Text(context.tTone('reviewExpense'))),
        body: Center(child: Text(context.tTone('noActiveCaseFound'))),
      );
    }

    final ref = CaseExpenseService.expensesCol(caseId).doc(widget.expenseId);
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('reviewExpense')),
        backgroundColor: PLDesign.surface,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(context.tTone('expenseNotFound')));
          }

          final data = snapshot.data!.data()!;
          final rawAmount = data['amount'];
          final amount = rawAmount is num
              ? rawAmount.toDouble()
              : double.tryParse('$rawAmount') ?? 0.0;
          final description = (data['description'] ?? 'Expense').toString();
          final status = (data['status'] ?? 'unpaid').toString();
          final receiptUrl = (data['receiptUrl'] ?? '').toString().trim();

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TrustNote(
                          text:
                              'Expenses are tracked with timestamps and full history for transparency.',
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: PLDesign.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: PLDesign.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                description,
                                style: PLDesign.sectionTitle,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${amount.toStringAsFixed(2)}',
                                style: PLDesign.heroTitle.copyWith(fontSize: 28),
                              ),
                              const SizedBox(height: 8),
                              Text('Current status: $status', style: PLDesign.caption),
                            ],
                          ),
                        ),
                        if (receiptUrl.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Receipt',
                            style: PLDesign.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: PLDesign.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => openExpenseReceiptFullscreen(
                              context,
                              imageUrl: receiptUrl,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: receiptUrl,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  height: 200,
                                  color: PLDesign.surface,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  height: 120,
                                  color: PLDesign.surface,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: PLDesign.textMuted,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Status changes are recorded for your case history.',
                          style: PLDesign.caption.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _setStatus(caseId: caseId, approved: true),
                          child: Text(context.tTone('approveExpense')),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _setStatus(caseId: caseId, approved: false),
                          child: Text(context.tTone('denyExpense')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
