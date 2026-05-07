import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class AttorneyCaseStatus {
  const AttorneyCaseStatus({
    required this.needsAttention,
    required this.issueCount,
    required this.lastActivityAt,
    required this.missedExchangeCount,
    required this.flaggedMessageCount,
    required this.unpaidExpenseCount,
    required this.healthScore,
    required this.riskScore,
    required this.riskLevel,
    required this.riskTrend,
  });

  final bool needsAttention;
  final int issueCount;
  final DateTime? lastActivityAt;

  /// Timeline events with type `exchange_missed` (recent window).
  final int missedExchangeCount;

  /// Messages with hostile / non-compliant legal flags (recent window).
  final int flaggedMessageCount;

  /// Unpaid expense rows (capped query).
  final int unpaidExpenseCount;

  /// 0–100 case health snapshot for counsel dashboards.
  final double healthScore;

  /// From `cases/{caseId}/insights/risk` — drives activity / spike signals.
  final int? riskScore;
  final String? riskLevel;
  final String riskTrend;

  /// One-line summary for client cards (counts concrete risks).
  String get keyStatSummary {
    final parts = <String>[];
    if (missedExchangeCount > 0) {
      parts.add(
        '$missedExchangeCount missed exchange${missedExchangeCount == 1 ? '' : 's'}',
      );
    }
    if (flaggedMessageCount > 0) {
      parts.add(
        '$flaggedMessageCount flagged msg${flaggedMessageCount == 1 ? '' : 's'}',
      );
    }
    if (unpaidExpenseCount > 0) {
      parts.add(
        '$unpaidExpenseCount unpaid expense${unpaidExpenseCount == 1 ? '' : 's'}',
      );
    }
    if (parts.isEmpty) return 'No open flags';
    return parts.take(3).join(' · ');
  }

  static double _deriveHealthScore({
    double? complianceScore,
    required int missedExchangeCount,
    required int flaggedMessageCount,
    required int unpaidExpenseCount,
    required int issueCount,
  }) {
    if (complianceScore != null &&
        complianceScore.isFinite &&
        complianceScore >= 0) {
      return complianceScore.clamp(0.0, 100.0);
    }
    var s = 100.0;
    s -= missedExchangeCount * 14;
    s -= flaggedMessageCount * 8;
    if (unpaidExpenseCount > 0) s -= 12;
    if (issueCount > 0) s -= 6;
    return s.clamp(0.0, 100.0);
  }
}

class AttorneyCaseStatusService {
  AttorneyCaseStatusService._();

  static final _db = FirebaseFirestore.instance;

  static Future<AttorneyCaseStatus> compute(String caseId) async {
    final caseRef = _db.collection('cases').doc(caseId);
    final caseSnap = await caseRef.get();
    final caseMap = caseSnap.data() ?? <String, dynamic>{};
    final complianceRaw = caseMap['complianceScore'];
    final complianceScore =
        complianceRaw is num ? complianceRaw.toDouble() : null;

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
    var missedExchangeCount = 0;
    var newViolation = false;
    for (final d in timelineSnap.docs) {
      final m = d.data();
      final ts = m['timestamp'];
      if (lastActivity == null && ts is Timestamp) {
        lastActivity = ts.toDate();
      }
      final type = (m['type'] ?? '').toString();
      if (type == 'exchange_missed') {
        missedExchangeCount++;
      }
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

    final flaggedMessageCount = msgSnap.docs.length;
    final risk = riskSnap.data();
    final riskTrendRaw = (risk?['riskTrend'] ?? 'stable').toString();
    final riskTrend =
        riskTrendRaw.isEmpty ? 'stable' : riskTrendRaw;
    final complianceDrop = riskTrend == 'up';
    final riskScoreRaw = risk?['riskScore'];
    final riskScore =
        riskScoreRaw is num ? riskScoreRaw.round() : null;
    final riskLevelRaw = risk?['riskLevel'];
    final riskLevel = riskLevelRaw?.toString().trim();

    final issueCount = (newViolation ? 1 : 0) +
        (unpaidExpenseCount > 0 ? 1 : 0) +
        (flaggedMessageCount > 0 ? 1 : 0) +
        (complianceDrop ? 1 : 0);
    final needsAttention = issueCount > 0;

    final healthScore = AttorneyCaseStatus._deriveHealthScore(
      complianceScore: complianceScore,
      missedExchangeCount: missedExchangeCount,
      flaggedMessageCount: flaggedMessageCount,
      unpaidExpenseCount: unpaidExpenseCount,
      issueCount: issueCount,
    );

    return AttorneyCaseStatus(
      needsAttention: needsAttention,
      issueCount: issueCount,
      lastActivityAt: lastActivity,
      missedExchangeCount: missedExchangeCount,
      flaggedMessageCount: flaggedMessageCount,
      unpaidExpenseCount: unpaidExpenseCount,
      healthScore: healthScore,
      riskScore: riskScore,
      riskLevel: riskLevel?.isEmpty == true ? null : riskLevel,
      riskTrend: riskTrend,
    );
  }

  /// Live refresh when the case document or risk insight doc changes.
  static Stream<AttorneyCaseStatus> watch(String caseId) {
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subCase;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subRisk;

    late final StreamController<AttorneyCaseStatus> controller;
    controller = StreamController<AttorneyCaseStatus>(
      onListen: () {
        final db = FirebaseFirestore.instance;
        final ref = db.collection('cases').doc(caseId);
        final riskRef = ref.collection('insights').doc('risk');

        Future<void> emit() async {
          try {
            final s = await compute(caseId);
            if (!controller.isClosed) controller.add(s);
          } catch (_) {}
        }

        subCase = ref.snapshots().listen((_) => emit());
        subRisk = riskRef.snapshots().listen((_) => emit());
        emit();
      },
      onCancel: () async {
        await subCase?.cancel();
        await subRisk?.cancel();
      },
    );

    return controller.stream;
  }
}

