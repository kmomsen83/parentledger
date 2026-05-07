import 'package:cloud_firestore/cloud_firestore.dart';

import 'case_paths.dart';
import 'crashlytics_service.dart';
import 'notification_service.dart';

/// Persists case compliance metrics to `cases/{caseId}/insights/risk`.
class CustodyRiskInsightsService {
  CustodyRiskInsightsService._();

  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> riskDoc(String caseId) =>
      _db
          .collection('cases')
          .doc(caseId)
          .collection('insights')
          .doc(CasePaths.insightsRiskDocId);

  /// Recompute from messages, exchanges, expenses — call after message/event or periodically.
  static Future<void> refresh(String caseId) async {
    final msgSnap = await _db
        .collection('cases')
        .doc(caseId)
        .collection('conversations')
        .doc(CasePaths.defaultConversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    final messages = msgSnap.docs.map((d) {
      final m = Map<String, dynamic>.from(d.data());
      m['messageId'] = d.id;
      return m;
    }).toList().reversed.toList();

    final exchangesSnap = await _db
        .collection('cases')
        .doc(caseId)
        .collection('exchanges')
        .limit(200)
        .get();

    final expensesSnap = await _db
        .collection('cases')
        .doc(caseId)
        .collection('expenses')
        .limit(200)
        .get();

    final checkInsSnap = await _db
        .collection('cases')
        .doc(caseId)
        .collection('exchange_checkins')
        .limit(120)
        .get();

    var lateExchangeCheckIns = 0;
    for (final d in checkInsSnap.docs) {
      final t = (d.data()['arrivalTiming'] ?? '').toString();
      if (t == 'late' || t == 'very_late') {
        lateExchangeCheckIns++;
      }
    }

    final now = DateTime.now();

    var missedExchanges = 0;
    var completedExchanges = 0;
    for (final d in exchangesSnap.docs) {
      final m = d.data();
      final status = (m['status'] ?? '').toString();
      final st = m['scheduledTime'];
      if (status == 'completed') {
        completedExchanges++;
        continue;
      }
      if (st is Timestamp) {
        if (st.toDate().isBefore(now) && status == 'scheduled') {
          missedExchanges++;
        }
      }
    }

    var unpaidExpenses = 0;
    var paidExpenses = 0;
    for (final d in expensesSnap.docs) {
      final m = d.data();
      final paid = m['paid'] == true || m['status'] == 'paid';
      if (paid) {
        paidExpenses++;
      } else {
        unpaidExpenses++;
      }
    }

    var flaggedMessages = 0;
    for (final m in messages) {
      final f = m['legalFlag']?.toString();
      if (f == 'hostile' || f == 'non-compliant') {
        flaggedMessages++;
      }
    }

    // Score 0–100: higher = more risk (message tone comes from server classifiers only).
    var score = 38;
    score += (flaggedMessages * 8).clamp(0, 36);
    score += missedExchanges * 12;
    score += (lateExchangeCheckIns * 5).clamp(0, 20);
    score += unpaidExpenses * 5;
    score -= (completedExchanges * 2).clamp(0, 15);
    score -= (paidExpenses * 1).clamp(0, 10);
    score = score.clamp(0, 100);

    String level;
    if (score < 35) {
      level = 'Low';
    } else if (score < 65) {
      level = 'Moderate';
    } else {
      level = 'High';
    }

    final prevSnap = await riskDoc(caseId).get();
    final prevMap = prevSnap.data();
    final previousScore = (prevMap?['riskScore'] as num?)?.toInt();
    final prevFactors = prevMap?['factors'] as Map<String, dynamic>?;
    final prevMissed =
        (prevFactors?['missedExchanges'] as num?)?.toInt() ?? 0;
    final prevLevel = prevMap?['riskLevel']?.toString();
    String riskTrend = 'stable';
    if (previousScore != null) {
      if (score > previousScore) {
        riskTrend = 'up';
      } else if (score < previousScore) {
        riskTrend = 'down';
      }
    }

    await riskDoc(caseId).set(
      <String, dynamic>{
        'riskScore': score,
        'previousRiskScore': previousScore,
        'riskTrend': riskTrend,
        'riskLevel': level,
        'updatedAt': FieldValue.serverTimestamp(),
        'factors': <String, dynamic>{
          'flaggedMessages': flaggedMessages,
          'missedExchanges': missedExchanges,
          'lateExchangeCheckIns': lateExchangeCheckIns,
          'completedExchanges': completedExchanges,
          'unpaidExpenses': unpaidExpenses,
          'paidExpenses': paidExpenses,
        },
      },
      SetOptions(merge: true),
    );

    try {
      if (missedExchanges > prevMissed) {
        await NotificationService.notifyCounselMissedExchanges(
          caseId: caseId,
          totalMissed: missedExchanges,
        );
      }
      if (previousScore != null) {
        final levelStr = level;
        if (prevLevel != null &&
            prevLevel.isNotEmpty &&
            prevLevel != levelStr) {
          await NotificationService.notifyCounselRiskActivity(
            caseId: caseId,
            summary:
                'Risk level changed from $prevLevel to $levelStr (score $previousScore → $score).',
          );
        } else {
          final delta = score - previousScore;
          if (delta >= 12 && score >= 55) {
            await NotificationService.notifyCounselRiskActivity(
              caseId: caseId,
              summary:
                  'Custody risk score increased materially ($previousScore → $score, $levelStr).',
            );
          }
        }
      }
    } catch (e, st) {
      await CrashlyticsService.recordError(
        e,
        st,
        reason: 'counsel custody risk notify',
      );
    }
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchRisk(String caseId) =>
      riskDoc(caseId).snapshots();
}
