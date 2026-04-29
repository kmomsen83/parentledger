import 'package:cloud_firestore/cloud_firestore.dart';

class AttorneyCaseStatus {
  const AttorneyCaseStatus({
    required this.needsAttention,
    required this.issueCount,
    required this.lastActivityAt,
  });

  final bool needsAttention;
  final int issueCount;
  final DateTime? lastActivityAt;
}

class AttorneyCaseStatusService {
  AttorneyCaseStatusService._();

  static final _db = FirebaseFirestore.instance;

  static Future<AttorneyCaseStatus> compute(String caseId) async {
    final caseRef = _db.collection('cases').doc(caseId);

    final timelineSnap = await caseRef
        .collection('timeline')
        .orderBy('timestamp', descending: true)
        .limit(120)
        .get();
    final expensesSnap = await caseRef.collection('expenses').limit(200).get();
    final msgSnap = await caseRef
        .collection('conversations')
        .doc('primary')
        .collection('messages')
        .where('legalFlag', whereIn: ['hostile', 'non-compliant'])
        .limit(20)
        .get();
    final riskSnap = await caseRef.collection('insights').doc('risk').get();

    DateTime? lastActivity;
    var newViolation = false;
    for (final d in timelineSnap.docs) {
      final m = d.data();
      final ts = m['timestamp'];
      if (lastActivity == null && ts is Timestamp) {
        lastActivity = ts.toDate();
      }
      final type = (m['type'] ?? '').toString();
      if (type == 'violation_flagged' || type == 'exchange_missed') {
        newViolation = true;
      }
    }

    var unpaidExpenseCount = 0;
    for (final d in expensesSnap.docs) {
      final m = d.data();
      final paid = m['paid'] == true || m['status'] == 'paid';
      if (!paid) unpaidExpenseCount++;
    }

    final flaggedMessages = msgSnap.docs.length;
    final risk = riskSnap.data();
    final riskTrend = (risk?['riskTrend'] ?? '').toString();
    final complianceDrop = riskTrend == 'up';

    final issueCount = (newViolation ? 1 : 0) +
        (unpaidExpenseCount > 0 ? 1 : 0) +
        (flaggedMessages > 0 ? 1 : 0) +
        (complianceDrop ? 1 : 0);
    final needsAttention = issueCount > 0;

    return AttorneyCaseStatus(
      needsAttention: needsAttention,
      issueCount: issueCount,
      lastActivityAt: lastActivity,
    );
  }
}

