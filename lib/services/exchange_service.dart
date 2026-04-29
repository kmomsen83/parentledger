import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/exchange_model.dart';
import '../models/case_event.dart';
import 'case_expense_service.dart';
import 'event_logger_service.dart';
import 'custody_risk_insights_service.dart';
import 'notification_service.dart';

/// One emission for the home dashboard: next exchange + expenses (replaces nested [StreamBuilder]s).
class DashboardHeaderTick {
  const DashboardHeaderTick({
    required this.nextExchange,
    required this.expenses,
    required this.exchangeLoading,
  });
  final ExchangeModel? nextExchange;
  final QuerySnapshot<Map<String, dynamic>> expenses;
  final bool exchangeLoading;
}

/// Custody exchanges: `cases/{caseId}/exchanges/{exchangeId}`.
class ExchangeService {
  ExchangeService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> exchangesCol(String caseId) =>
      _db.collection('cases').doc(caseId).collection('exchanges');

  static Future<String> createExchange({
    required String caseId,
    required String childId,
    required DateTime scheduledTime,
    required String type,
    required String locationName,
    String? address,
    String? placeId,
    required double lat,
    required double lng,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final resolvedAddress = (address ?? locationName).trim();

    final ref = await exchangesCol(caseId).add(<String, dynamic>{
      'caseId': caseId,
      'childId': childId,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'type': type,
      'locationName': locationName,
      'address': resolvedAddress.isNotEmpty ? resolvedAddress : locationName,
      if (placeId != null && placeId.isNotEmpty) 'placeId': placeId,
      'lat': lat,
      'lng': lng,
      'status': 'scheduled',
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await EventLoggerService.logEventForActor(
        caseId: caseId,
        type: CaseEventTypes.scheduleCreated,
        title: 'Schedule created',
        description:
            '${type.trim()} at ${locationName.trim()}'.trim().isEmpty
                ? 'Custody exchange scheduled'
                : '${type.trim()} at ${locationName.trim()}'.trim(),
        actorId: uid,
        metadata: <String, dynamic>{
          'scheduleId': ref.id,
          'exchangeId': ref.id,
          'date': scheduledTime.toIso8601String().split('T').first,
          'time': scheduledTime.toIso8601String(),
          'location': locationName,
          'childId': childId,
          'exchangeType': type,
        },
      );
    } catch (_) {
      await ref.delete();
      rethrow;
    }

    await NotificationService.notifyExchangeScheduled(
      caseId: caseId,
      createdBy: uid,
      exchangeId: ref.id,
      scheduledTime: scheduledTime,
    );

    unawaited(CustodyRiskInsightsService.refresh(caseId));
    return ref.id;
  }

  static Future<void> deleteExchange({
    required String caseId,
    required String exchangeId,
  }) async {
    throw UnsupportedError(
      'Exchange deletion is disabled to preserve the legal record.',
    );
  }

  static Future<void> updateExchange({
    required String caseId,
    required String exchangeId,
    DateTime? scheduledTime,
    String? type,
    String? locationName,
    String? address,
    String? placeId,
    double? lat,
    double? lng,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final data = <String, dynamic>{};

    if (scheduledTime != null) {
      data['scheduledTime'] = Timestamp.fromDate(scheduledTime);
    }
    if (type != null) data['type'] = type;
    if (locationName != null) data['locationName'] = locationName;
    if (address != null) data['address'] = address;
    if (placeId != null) data['placeId'] = placeId;
    if (lat != null) data['lat'] = lat;
    if (lng != null) data['lng'] = lng;

    if (data.isEmpty) return;

    final exRef = exchangesCol(caseId).doc(exchangeId);
    final priorSnap = await exRef.get();
    final prior = priorSnap.data();
    if (prior == null) throw StateError('Exchange not found');
    final priorCopy = Map<String, dynamic>.from(prior);

    await exRef.update(data);

    final snap = await exRef.get();
    final m = snap.data() ?? <String, dynamic>{};
    final st = m['scheduledTime'];
    final scheduled = st is Timestamp ? st.toDate() : DateTime.now();
    final loc = (m['locationName'] ?? locationName ?? '').toString();
    final typ = (m['type'] ?? type ?? '').toString();
    try {
      await EventLoggerService.logEventForActor(
        caseId: caseId,
        type: CaseEventTypes.scheduleUpdated,
        title: 'Schedule updated',
        description:
            loc.isEmpty ? 'Custody exchange was updated' : 'Updated: $loc',
        actorId: uid,
        metadata: <String, dynamic>{
          'scheduleId': exchangeId,
          'exchangeId': exchangeId,
          'date': scheduled.toIso8601String().split('T').first,
          'time': scheduled.toIso8601String(),
          'location': loc,
          'exchangeType': typ,
        },
      );
    } catch (_) {
      await exRef.set(priorCopy);
      rethrow;
    }
  }

  /// IMPORTANT: Each call returns a new stream (single listener). Use one [StreamBuilder]
  /// per scope, or nest a parent [StreamBuilder] and pass data down — do not attach multiple
  /// [StreamBuilder]s to streams derived from the same listener expectation.
  static Stream<List<ExchangeModel>> watchUpcoming(String caseId) {
    return exchangesCol(caseId)
        .where('scheduledTime', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('scheduledTime')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ExchangeModel.fromDoc(d, caseId: caseId))
              .toList(),
        );
  }

  /// IMPORTANT: Single-subscription chain from [watchUpcoming]. One [StreamBuilder] per UI scope.
  static Stream<ExchangeModel?> watchNextExchange(String caseId) {
    return watchUpcoming(caseId).map((list) {
      if (list.isEmpty) return null;
      return list.first;
    });
  }

  /// Single stream for [DashboardScreen] header — merges next exchange + expense query so the UI
  /// does not nest two [StreamBuilder]s on separate Firestore listeners (scroll/rebuild races).
  static Stream<DashboardHeaderTick> watchDashboardHeader(String caseId) {
    final controller = StreamController<DashboardHeaderTick>();
    ExchangeModel? lastEx;
    var exchangeInitialized = false;
    QuerySnapshot<Map<String, dynamic>>? lastExp;

    void emit() {
      final exp = lastExp;
      if (exp == null) return;
      controller.add(
        DashboardHeaderTick(
          nextExchange: lastEx,
          expenses: exp,
          exchangeLoading: !exchangeInitialized,
        ),
      );
    }

    late final StreamSubscription<ExchangeModel?> subEx;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subExp;

    subEx = watchNextExchange(caseId).listen(
      (x) {
        lastEx = x;
        exchangeInitialized = true;
        emit();
      },
      onError: controller.addError,
    );
    subExp = CaseExpenseService.watchExpenses(caseId).listen(
      (s) {
        lastExp = s;
        emit();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await subEx.cancel();
      await subExp.cancel();
    };

    return controller.stream;
  }

  static Future<void> checkIn({
    required String caseId,
    required String exchangeId,
    required double actualLat,
    required double actualLng,
    bool logTimelineEvent = true,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final exRef = exchangesCol(caseId).doc(exchangeId);
    final priorSnap = await exRef.get();
    final prior = priorSnap.data();
    if (prior == null) throw StateError('Exchange not found');
    final priorCopy = Map<String, dynamic>.from(prior);

    await exRef.update(<String, dynamic>{
      'status': 'completed',
      'arrivalLat': actualLat,
      'arrivalLng': actualLng,
      'checkedInAt': FieldValue.serverTimestamp(),
    });

    if (logTimelineEvent) {
      try {
        await EventLoggerService.logEventForActor(
          caseId: caseId,
          type: CaseEventTypes.statusChange,
          title: 'Exchange completed',
          description: 'Check-in recorded for the scheduled exchange.',
          actorId: uid,
          metadata: <String, dynamic>{
            'exchangeId': exchangeId,
            'arrivalLat': actualLat,
            'arrivalLng': actualLng,
          },
        );
      } catch (_) {
        await exRef.set(priorCopy);
        rethrow;
      }
    }

    unawaited(CustodyRiskInsightsService.refresh(caseId));
  }

  /// All exchanges for attorney / reporting views (newest scheduled first).
  /// IMPORTANT: Firestore [snapshots] is single-listener per returned stream; one consumer.
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchAllExchanges(
    String caseId,
  ) =>
      exchangesCol(caseId)
          .orderBy('scheduledTime', descending: true)
          .snapshots();
}
