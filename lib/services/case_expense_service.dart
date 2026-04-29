import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/case_event.dart';
import '../util/subscription_limits.dart';
import 'event_logger_service.dart';
import 'custody_risk_insights_service.dart';
import 'notification_service.dart';

/// `cases/{caseId}/expenses/{expenseId}`
class CaseExpenseService {
  CaseExpenseService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> expensesCol(String caseId) =>
      _db.collection('cases').doc(caseId).collection('expenses');

  /// Count of expense documents (for free-tier enforcement).
  static Future<int> expenseDocumentCount(String caseId) async {
    final agg = await expensesCol(caseId).count().get();
    return agg.count ?? 0;
  }

  /// Whether another expense row may be added for this case (aligned with [createCaseExpense]).
  static Future<bool> canAddExpense(
    String caseId, {
    required bool hasFullSubscriptionAccess,
  }) async {
    if (hasFullSubscriptionAccess) return true;
    final n = await expenseDocumentCount(caseId);
    return n < SubscriptionLimits.freeMaxExpenses;
  }

  static Future<void> addExpense({
    required String caseId,
    required double amount,
    required String description,
    bool paid = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('createCaseExpense');
    final result = await callable.call(<String, dynamic>{
      'caseId': caseId,
      'amount': amount,
      'description': description,
      'paid': paid,
    });
    final map = Map<String, dynamic>.from(
      (result.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    final expenseId = (map['expenseId'] ?? '').toString();
    if (expenseId.isEmpty) {
      throw StateError('createCaseExpense did not return expenseId');
    }

    await NotificationService.notifyExpenseCreated(
      caseId: caseId,
      createdBy: uid,
      expenseId: expenseId,
      amount: amount,
      description: description,
    );

    await CustodyRiskInsightsService.refresh(caseId);
  }

  // IMPORTANT: Each call returns a new [Stream] (new Firestore listen). The dashboard uses
  // one parent [StreamBuilder] and passes [AsyncSnapshot] to children — do not add a second
  // [StreamBuilder] on [watchExpenses] for the same case on that screen.
  /// Firestore query snapshot stream — **single subscription** per returned stream.
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchExpenses(String caseId) =>
      expensesCol(caseId).orderBy('createdAt', descending: true).snapshots();

  /// Simple **50/50** model for unpaid rows: whoever logged an expense is owed half
  /// by the co-parent until [paid]. Positive = [uid] is owed money on net.
  static double netSplitBalanceForUser({
    required String uid,
    required String? coparentUid,
    required Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  }) {
    if (coparentUid == null || coparentUid.isEmpty) return 0;
    var net = 0.0;
    for (final doc in docs) {
      final e = doc.data();
      final paid = e['paid'] == true || e['status'] == 'paid';
      if (paid) continue;
      final amount = (e['amount'] is num)
          ? (e['amount'] as num).toDouble()
          : double.tryParse('${e['amount']}') ??
              0.0;
      final half = amount / 2.0;
      final createdBy = e['createdBy']?.toString();
      if (createdBy == uid) {
        net += half;
      } else if (createdBy == coparentUid) {
        net -= half;
      }
    }
    return net;
  }

  static Future<void> setPaid({
    required String caseId,
    required String expenseId,
    required bool paid,
  }) async {
    await setStatus(
      caseId: caseId,
      expenseId: expenseId,
      status: paid ? 'paid' : 'unpaid',
    );
  }

  static Future<void> setStatus({
    required String caseId,
    required String expenseId,
    required String status,
  }) async {
    final expenseRef = expensesCol(caseId).doc(expenseId);
    final snap = await expenseRef.get();
    if (!snap.exists) throw StateError('Expense not found');
    final data = snap.data() ?? const <String, dynamic>{};
    final creatorUid = (data['createdBy'] ?? '').toString();
    final normalized = status.toLowerCase().trim();
    final paid = normalized == 'paid';

    final priorCopy = Map<String, dynamic>.from(data);

    await expenseRef.update(<String, dynamic>{
      'paid': paid,
      'status': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final expenseAmount = (data['amount'] is num)
        ? (data['amount'] as num).toDouble()
        : double.tryParse('${data['amount']}') ?? 0.0;
    final expenseTitle = (data['description'] ?? '').toString();

    try {
      if (normalized == 'paid') {
        await EventLoggerService.logEventForActor(
          caseId: caseId,
          type: CaseEventTypes.expenseApproved,
          title: 'Expense approved',
          description: expenseTitle.isEmpty
              ? 'Expense marked approved (\$${expenseAmount.toStringAsFixed(2)}).'
              : expenseTitle,
          actorId: uid,
          metadata: <String, dynamic>{
            'expenseId': expenseId,
            'amount': expenseAmount,
            'title': expenseTitle,
            'status': normalized,
          },
        );
      } else if (normalized == 'denied') {
        await EventLoggerService.logEventForActor(
          caseId: caseId,
          type: CaseEventTypes.expenseDenied,
          title: 'Expense denied',
          description: expenseTitle.isEmpty
              ? 'Expense was denied (\$${expenseAmount.toStringAsFixed(2)}).'
              : expenseTitle,
          actorId: uid,
          metadata: <String, dynamic>{
            'expenseId': expenseId,
            'amount': expenseAmount,
            'title': expenseTitle,
            'status': normalized,
          },
        );
      }
    } catch (_) {
      await expenseRef.set(priorCopy);
      rethrow;
    }

    if (creatorUid.isNotEmpty && creatorUid != uid) {
      await NotificationService.notifyExpenseStatusChanged(
        caseId: caseId,
        expenseId: expenseId,
        creatorUid: creatorUid,
        approved: paid,
      );
    }

    await CustodyRiskInsightsService.refresh(caseId);
  }
}
