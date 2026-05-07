import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/exchange_model.dart';
import 'exchange_service.dart';

/// Deterministic custody / schedule queries over exchanges + stored patterns.
class CalendarEngineService {
  CalendarEngineService._();

  static final _db = FirebaseFirestore.instance;

  /// Pattern taxonomy persisted under `cases/{id}/recurring_patterns`.
  static const weekly = 'weekly';
  static const biweekly = 'biweekly';
  static const everyOtherWeekend = 'every_other_weekend';
  static const twoTwoFiveFive = '2-2-5-5';
  static const threeFourFourThree = '3-4-4-3';
  static const custom = 'custom';

  static Future<CustodySnapshot?> getCurrentCustody({
    required String caseId,
    DateTime? at,
  }) async {
    final t = at ?? DateTime.now();
    final startOfDay = DateTime(t.year, t.month, t.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snap = await _db
        .collection('cases')
        .doc(caseId)
        .collection('exchanges')
        .where(
          'scheduledTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where(
          'scheduledTime',
          isLessThan: Timestamp.fromDate(endOfDay),
        )
        .get();

    if (snap.docs.isEmpty) {
      return CustodySnapshot(
        at: t,
        label: 'No exchange on this day',
        nextExchange: await getNextExchange(caseId),
      );
    }

    final items = snap.docs
        .map((d) => ExchangeModel.fromDoc(d, caseId: caseId))
        .toList()
      ..sort(
        (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
      );

    ExchangeModel? active;
    for (final e in items) {
      if (!e.scheduledTime.isAfter(t) &&
          (e.status == 'scheduled' || e.status == 'completed')) {
        active = e;
        break;
      }
    }

    return CustodySnapshot(
      at: t,
      label: active != null
          ? 'Scheduled exchange ${active.scheduledTime.hour}:${active.scheduledTime.minute.toString().padLeft(2, '0')}'
          : 'Custody window — see schedule',
      activeExchange: active,
      nextExchange: await getNextExchange(caseId),
    );
  }

  static Future<ExchangeModel?> getNextExchange(String caseId) async {
    final list = await ExchangeService.watchUpcoming(caseId).first;
    if (list.isEmpty) return null;
    return list.first;
  }

  /// Overlapping exchanges same child same window (same calendar day overlap heuristic).
  static Future<List<List<String>>> validateScheduleConflicts(String caseId) async {
    final snap = await _db
        .collection('cases')
        .doc(caseId)
        .collection('exchanges')
        .where(
          'scheduledTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
        )
        .get();

    final byDay = <String, List<String>>{};
    for (final d in snap.docs) {
      final m = d.data();
      final st = m['scheduledTime'];
      final childId = (m['childId'] ?? '').toString();
      if (st is! Timestamp) continue;
      final dt = st.toDate();
      final key = '${dt.year}-${dt.month}-${dt.day}_$childId';
      byDay.putIfAbsent(key, () => []).add(d.id);
    }
    final conflicts = <List<String>>[];
    for (final e in byDay.entries) {
      if (e.value.length > 1) conflicts.add(e.value);
    }
    return conflicts;
  }
}

class CustodySnapshot {
  const CustodySnapshot({
    required this.at,
    required this.label,
    this.activeExchange,
    this.nextExchange,
  });

  final DateTime at;
  final String label;
  final ExchangeModel? activeExchange;
  final ExchangeModel? nextExchange;
}
