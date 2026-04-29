import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';
import '../services/case_expense_service.dart';

class AttorneyUnpaidExpensesScreen extends StatelessWidget {
  const AttorneyUnpaidExpensesScreen({
    super.key,
    required this.caseId,
  });

  final String caseId;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('unpaidSharedExpenses')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final unpaid = snap.data!.docs.where((d) {
            final m = d.data();
            final paid = m['paid'] == true || m['status'] == 'paid';
            return !paid;
          }).toList();

          if (unpaid.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No unpaid expenses in the current case record.',
                  style: PLDesign.body.copyWith(height: 1.35),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: unpaid.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doc = unpaid[i];
              final m = doc.data();
              final desc = (m['description'] ?? '').toString();
              final a = m['amount'];
              final amt = a is num ? a.toDouble() : double.tryParse('$a') ?? 0.0;
              final created = m['createdAt'];
              String when = '—';
              if (created is Timestamp) when = df.format(created.toDate());

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PLDesign.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PLDesign.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            desc.isEmpty ? 'Expense' : desc,
                            style: PLDesign.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text('Recorded $when', style: PLDesign.caption),
                        ],
                      ),
                    ),
                    Text(
                      '\$${amt.toStringAsFixed(2)}',
                      style: PLDesign.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: PLDesign.warning,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
