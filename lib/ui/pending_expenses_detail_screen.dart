import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/case_expense_service.dart';
import 'approve_deny_expense_screen.dart';

/// Lists unpaid case expenses with running total (Firestore-backed).
class PendingExpensesDetailScreen extends StatelessWidget {
  const PendingExpensesDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId;
    final df = DateFormat.yMMMd();

    return Scaffold(
      backgroundColor: PLDesign.background,
      body: Container(
        decoration: const BoxDecoration(gradient: PLDesign.pageGradient),
        child: SafeArea(
          child: caseId == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No case linked. Complete setup to view pending expenses.',
                      style: PLDesign.body.copyWith(height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: CaseExpenseService.watchExpenses(caseId),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          '${snap.error}',
                          style: PLDesign.body.copyWith(color: PLDesign.danger),
                        ),
                      );
                    }
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    final unpaid = docs.where((d) {
                      final m = d.data();
                      final paid = m['paid'] == true || m['status'] == 'paid';
                      return !paid;
                    }).toList();

                    var total = 0.0;
                    for (final d in unpaid) {
                      final m = d.data();
                      final a = m['amount'];
                      if (a is num) {
                        total += a.toDouble();
                      } else {
                        total += double.tryParse('$a') ?? 0;
                      }
                    }

                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new,
                                      color: Colors.white70),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const Expanded(
                                  child: Text(
                                    'Pending expenses',
                                    style: PLDesign.pageTitle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: PLDesign.elevatedCard,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '\$${total.toStringAsFixed(2)}',
                                    style: PLDesign.statNumber,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    unpaid.isEmpty
                                        ? 'No outstanding shared expenses'
                                        : '${unpaid.length} unpaid entr${unpaid.length == 1 ? 'y' : 'ies'}',
                                    style: PLDesign.caption,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (unpaid.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  'All recorded expenses are marked paid, or none have been added yet.',
                                  style: PLDesign.body.copyWith(height: 1.35),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final doc = unpaid[i];
                                  final m = doc.data();
                                  final desc =
                                      (m['description'] ?? 'Expense').toString();
                                  final a = m['amount'];
                                  final amt = a is num
                                      ? a.toDouble()
                                      : double.tryParse('$a') ?? 0.0;
                                  final created = m['createdAt'];
                                  String when = '—';
                                  if (created is Timestamp) {
                                    when = df.format(created.toDate());
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Material(
                                      color: PLDesign.card,
                                      borderRadius: BorderRadius.circular(16),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 8,
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                desc,
                                                style: PLDesign.body.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '\$${amt.toStringAsFixed(2)}',
                                              style: PLDesign.body.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Text(
                                          'Recorded $when',
                                          style: PLDesign.caption,
                                        ),
                                        trailing: TextButton(
                                          onPressed: () async {
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
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: unpaid.length,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
