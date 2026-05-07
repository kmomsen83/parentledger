import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/case_expense_service.dart';
import '../services/case_switcher_service.dart';
import '../services/export_service.dart';
import 'package:printing/printing.dart';
import 'approve_deny_expense_screen.dart';
import 'submit_expense_screen.dart';
import 'widgets/attorney_case_switcher.dart';
import 'widgets/expense_receipt_fullscreen.dart';
import 'widgets/premium_upgrade_sheet.dart';
import 'widgets/trust_elements.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  bool _selectMode = false;
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _gateFreeTierParent());
  }

  Future<void> _gateFreeTierParent() async {
    if (!mounted) return;
    final s = context.read<CaseContext>();
    if (s.isAttorney || s.unlockedParentPremiumFeatures) return;
    await showPremiumUpgradeSheet(
      context,
      feature: DashboardPremiumFeature.expenseLedger,
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _openSubmitExpense() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SubmitExpenseScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final switchedCaseId = context.watch<CaseSwitcherService>().selectedCaseId;
    final caseId = session.isAttorney
        ? (switchedCaseId ?? session.caseId)
        : session.caseId;
    final df = DateFormat.yMMMd().add_jm();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('sharedExpenses')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
        actions: [
          const AttorneyCaseSwitcher(),
          if (_selectMode)
            IconButton(
              tooltip: 'Select all',
              icon: const Icon(Icons.select_all),
              onPressed: () {
                // no-op here, handled from list builder on current docs
              },
            )
          else
            IconButton(
              tooltip: 'Bulk select',
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() {
                _selectMode = true;
                _selected.clear();
              }),
            ),
          IconButton(
            tooltip: 'Add expense',
            icon: const Icon(Icons.add_rounded),
            onPressed: caseId == null ? null : _openSubmitExpense,
          ),
        ],
      ),
      body: caseId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No case linked. Complete workspace setup to track expenses.',
                  style: PLDesign.body.copyWith(height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: TrustNote(
                    text:
                        'Expenses are tracked with timestamps and full history for transparency.',
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: CaseExpenseService.watchExpenses(caseId),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snap.error}',
                            style:
                                PLDesign.body.copyWith(color: PLDesign.danger),
                          ),
                        );
                      }
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 56,
                                  color: PLDesign.textMuted,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No expenses logged yet — all entries are tracked with history',
                                  style: PLDesign.sectionTitle
                                      .copyWith(fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Track and split costs with clear records for review.',
                                  style:
                                      PLDesign.caption.copyWith(height: 1.35),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: _openSubmitExpense,
                                  child: Text(context.tTone('addFirstExpense')),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final e = doc.data();
                          final paid =
                              e['paid'] == true || e['status'] == 'paid';
                          final denied = e['status'] == 'denied';
                          final amount = (e['amount'] is num)
                              ? (e['amount'] as num).toDouble()
                              : double.tryParse('${e['amount']}') ?? 0.0;
                          final desc = (e['description'] ?? '').toString();
                          final created = e['createdAt'];
                          final receiptUrl = (e['receiptUrl'] ?? '').toString().trim();
                          String whenLabel = '—';
                          if (created is Timestamp) {
                            whenLabel = df.format(created.toDate());
                          }

                          final selected = _selected.contains(doc.id);
                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: PLDesign.card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? PLDesign.primary
                                    : PLDesign.border,
                                width: selected ? 1.6 : 1,
                              ),
                              boxShadow: PLDesign.softShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        desc.isEmpty ? 'Expense' : desc,
                                        style: PLDesign.body.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (receiptUrl.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () =>
                                            openExpenseReceiptFullscreen(
                                          context,
                                          imageUrl: receiptUrl,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: receiptUrl,
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              width: 52,
                                              height: 52,
                                              alignment: Alignment.center,
                                              child: const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                              width: 52,
                                              height: 52,
                                              color: PLDesign.surface,
                                              child: Icon(
                                                Icons.receipt_long,
                                                color: PLDesign.textMuted,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 8),
                                    Text(
                                      '\$${amount.toStringAsFixed(2)}',
                                      style: PLDesign.body.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  whenLabel,
                                  style: PLDesign.caption,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: paid
                                            ? PLDesign.success
                                                .withValues(alpha: 0.15)
                                            : denied
                                                ? PLDesign.danger
                                                    .withValues(alpha: 0.15)
                                                : PLDesign.warning
                                                    .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        paid
                                            ? 'Paid'
                                            : denied
                                                ? 'Denied'
                                                : 'Unpaid',
                                        style: PLDesign.caption.copyWith(
                                          color: paid
                                              ? PLDesign.success
                                              : denied
                                                  ? PLDesign.danger
                                                  : PLDesign.warning,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!paid)
                                      TextButton(
                                        onPressed: () async {
                                          if (_selectMode) {
                                            setState(() {
                                              if (selected) {
                                                _selected.remove(doc.id);
                                              } else {
                                                _selected.add(doc.id);
                                              }
                                            });
                                            return;
                                          }
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ApproveDenyExpenseScreen(
                                                expenseId: doc.id,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Text(context.tTone('review')),
                                      )
                                    else
                                      TextButton(
                                        onPressed: () async {
                                          if (_selectMode) {
                                            setState(() {
                                              if (selected) {
                                                _selected.remove(doc.id);
                                              } else {
                                                _selected.add(doc.id);
                                              }
                                            });
                                            return;
                                          }
                                          try {
                                            await CaseExpenseService.setPaid(
                                              caseId: caseId,
                                              expenseId: doc.id,
                                              paid: false,
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Status changes are recorded for your case history.',
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (err) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(content: Text('$err')),
                                              );
                                            }
                                          }
                                        },
                                        child:
                                            Text(context.tTone('markUnpaid')),
                                      ),
                                    if (_selectMode)
                                      Checkbox(
                                        value: selected,
                                        onChanged: (_) {
                                          setState(() {
                                            if (selected) {
                                              _selected.remove(doc.id);
                                            } else {
                                              _selected.add(doc.id);
                                            }
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _selectMode && caseId != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _selectMode = false;
                          _selected.clear();
                        }),
                        child: const Text('Done'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _selected.isEmpty
                            ? null
                            : () async {
                                final ids = _selected.take(10).toList();
                                final snap = await FirebaseFirestore.instance
                                    .collection('cases')
                                    .doc(caseId)
                                    .collection('expenses')
                                    .where(FieldPath.documentId, whereIn: ids)
                                    .get();
                                final rows = snap.docs.map((d) {
                                  final m = d.data();
                                  final ts = m['createdAt'];
                                  return ExportRow(
                                    type: 'expense',
                                    date: ts is Timestamp ? ts.toDate() : null,
                                    description: (m['description'] ?? 'Expense')
                                        .toString(),
                                    amount: (m['amount'] is num)
                                        ? (m['amount'] as num).toDouble()
                                        : null,
                                    tags: List<String>.from(
                                        m['tags'] ?? const []),
                                    evidence: m['evidence'] == true,
                                  );
                                }).toList();
                                final pdf = await ExportService.buildPdf(
                                  caseTitle: 'Case $caseId',
                                  childrenCount: 0,
                                  rows: rows,
                                );
                                await Printing.sharePdf(
                                  bytes: pdf,
                                  filename: 'expenses_$caseId.pdf',
                                );
                                final csv = ExportService.buildCsv(rows);
                                await Clipboard.setData(
                                  ClipboardData(
                                      text: String.fromCharCodes(csv)),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('PDF shared and CSV copied.'),
                                  ),
                                );
                              },
                        child: const Text('Export'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
