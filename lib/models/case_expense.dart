import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/case_expense_service.dart';

/// `cases/{caseId}/expenses/{expenseId}` — read-only view of common fields.
class CaseExpense {
  const CaseExpense({
    required this.id,
    required this.amount,
    required this.description,
    required this.paid,
    required this.status,
    this.receiptUrl,
  });

  final String id;
  final double amount;
  final String description;
  final bool paid;
  final String status;
  final String? receiptUrl;

  static CaseExpense? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) return null;
    final m = doc.data() ?? {};
    final rawAmount = m['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse('$rawAmount') ?? 0.0;
    return CaseExpense(
      id: doc.id,
      amount: amount,
      description: (m['description'] ?? '').toString(),
      paid: m['paid'] == true,
      status: (m['status'] ?? 'unpaid').toString(),
      receiptUrl: CaseExpenseService.receiptImageUrlFrom(m),
    );
  }
}
