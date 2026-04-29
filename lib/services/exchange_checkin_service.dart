import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/exchange_checkin_record.dart';
import '../models/exchange_checkin_submit_result.dart';
import '../models/case_event.dart';
import 'event_logger_service.dart';
import 'custody_risk_insights_service.dart';
import 'exchange_service.dart';

/// Immutable custody exchange check-ins: `cases/{caseId}/exchange_checkins/{id}`.
class ExchangeCheckinService {
  ExchangeCheckinService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> checkInsCol(String caseId) =>
      _db.collection('cases').doc(caseId).collection('exchange_checkins');

  static Reference _photoRef(String caseId, String checkInId, String fileName) =>
      FirebaseStorage.instance
          .ref()
          .child('cases')
          .child(caseId)
          .child('exchange_checkins')
          .child(checkInId)
          .child(fileName);

  /// Relative to scheduled exchange start (minutes, positive = after scheduled time).
  static String? arrivalTimingLabel({
    required DateTime scheduled,
    required DateTime at,
  }) {
    final m = at.difference(scheduled).inMinutes;
    if (m < -30) return 'very_early';
    if (m < -15) return 'early';
    if (m <= 15) return 'on_time';
    if (m <= 60) return 'late';
    return 'very_late';
  }

  static String computeContentHash(Map<String, dynamic> canonical) {
    final sortedKeys = canonical.keys.toList()..sort();
    final ordered = <String, dynamic>{
      for (final k in sortedKeys) k: canonical[k],
    };
    return sha256.convert(utf8.encode(jsonEncode(ordered))).toString();
  }

  /// Persists an immutable check-in, timeline event, optional risk flag for late arrival,
  /// and completes the linked exchange when appropriate.
  static Future<ExchangeCheckinSubmitResult> submit({
    required String caseId,
    String? exchangeId,
    required ExchangeCheckinVerificationStatus verificationStatus,
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    required DateTime deviceTimestamp,
    String? photoLocalPath,
    String? note,
    String? handoffType,
    double? distanceFromExpectedMeters,
    String? expectedLocationName,
    String? recordedAddress,
    DateTime? scheduledTime,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');
    final currentUserId = user.uid;
    final userRef = _db.collection('users').doc(currentUserId);
    Map<String, dynamic>? userBefore;
    try {
      final beforeSnap = await userRef.get();
      userBefore = beforeSnap.data();
      if (kDebugMode) {
        debugPrint(
          '[ExchangeCheckin] before submit uid=$currentUserId userDoc=$userBefore',
        );
      }
    } catch (_) {}

    final checkInRef = checkInsCol(caseId).doc();
    final checkInId = checkInRef.id;

    String? photoUrl;
    if (photoLocalPath != null && photoLocalPath.isNotEmpty) {
      final file = File(photoLocalPath);
      if (await file.exists()) {
        final safeName =
            'evidence_${DateTime.now().millisecondsSinceEpoch}.jpg'
                .replaceAll(RegExp(r'[/\\]'), '_');
        final ref = _photoRef(caseId, checkInId, safeName);
        await ref.putFile(file);
        photoUrl = await ref.getDownloadURL();
      }
    }

    final resolvedAddress = (recordedAddress ?? expectedLocationName ?? '').trim();

    int? minutesFromScheduled;
    String? arrivalTiming;
    if (scheduledTime != null) {
      minutesFromScheduled =
          deviceTimestamp.difference(scheduledTime).inMinutes;
      arrivalTiming = arrivalTimingLabel(
        scheduled: scheduledTime,
        at: deviceTimestamp,
      );
    }

    final deviceInfoJson = deviceInfo == null || deviceInfo.isEmpty
        ? null
        : Map<String, dynamic>.from(deviceInfo);

    final canonicalForHash = <String, dynamic>{
      'userId': user.uid,
      'deviceTimestamp': deviceTimestamp.toUtc().toIso8601String(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationAccuracy != null) 'locationAccuracy': locationAccuracy,
      if (exchangeId != null) 'exchangeId': exchangeId,
      'verificationStatus': verificationStatus.firestoreValue,
      if (photoUrl != null) 'photoEvidenceUrl': photoUrl,
      if (note != null && note.isNotEmpty) 'note': note,
      if (handoffType != null) 'handoffType': handoffType,
      if (distanceFromExpectedMeters != null)
        'distanceFromExpectedMeters': distanceFromExpectedMeters,
      if (expectedLocationName != null) 'expectedLocationName': expectedLocationName,
      if (resolvedAddress.isNotEmpty) 'recordedAddress': resolvedAddress,
      if (scheduledTime != null)
        'scheduledTime': scheduledTime.toUtc().toIso8601String(),
      if (arrivalTiming != null) 'arrivalTiming': arrivalTiming,
      if (minutesFromScheduled != null)
        'minutesFromScheduled': minutesFromScheduled,
      if (deviceInfoJson != null) 'deviceInfo': deviceInfoJson,
    };

    final hash = computeContentHash(canonicalForHash);

    await checkInRef.set(<String, dynamic>{
      'userId': user.uid,
      'deviceTimestamp': Timestamp.fromDate(deviceTimestamp),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationAccuracy != null) 'locationAccuracy': locationAccuracy,
      if (exchangeId != null) 'exchangeId': exchangeId,
      'verificationStatus': verificationStatus.firestoreValue,
      if (photoUrl != null) 'photoEvidenceUrl': photoUrl,
      if (note != null && note.isNotEmpty) 'note': note,
      if (handoffType != null) 'handoffType': handoffType,
      if (distanceFromExpectedMeters != null)
        'distanceFromExpectedMeters': distanceFromExpectedMeters,
      if (expectedLocationName != null) 'expectedLocationName': expectedLocationName,
      if (resolvedAddress.isNotEmpty) 'recordedAddress': resolvedAddress,
      if (scheduledTime != null)
        'scheduledTime': Timestamp.fromDate(scheduledTime),
      if (arrivalTiming != null) 'arrivalTiming': arrivalTiming,
      if (minutesFromScheduled != null)
        'minutesFromScheduled': minutesFromScheduled,
      if (deviceInfoJson != null) 'deviceInfo': deviceInfoJson,
      'hash': hash,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final timelineMeta = <String, dynamic>{
      'checkInId': checkInId,
      'verificationStatus': verificationStatus.firestoreValue,
      if (exchangeId != null) 'exchangeId': exchangeId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationAccuracy != null) 'locationAccuracy': locationAccuracy,
      if (photoUrl != null) 'hasPhotoEvidence': true,
      if (note != null && note.isNotEmpty) 'hasNote': true,
      if (handoffType != null) 'handoffType': handoffType,
      if (resolvedAddress.isNotEmpty) 'recordedAddress': resolvedAddress,
      if (arrivalTiming != null) 'arrivalTiming': arrivalTiming,
      if (minutesFromScheduled != null)
        'minutesFromScheduled': minutesFromScheduled,
      'contentHash': hash,
    };

    try {
      await EventLoggerService.logEventForActor(
        caseId: caseId,
        type: CaseEventTypes.statusChange,
        title: 'Exchange check-in recorded',
        description:
            'Custody exchange check-in submitted (${verificationStatus.firestoreValue}).',
        actorId: user.uid,
        metadata: <String, dynamic>{
          ...timelineMeta,
          'eventSubtype': 'exchange_checkin_completed',
        },
      );
    } catch (_) {
      await checkInRef.delete();
      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(photoUrl).delete();
        } catch (_) {}
      }
      rethrow;
    }

    if (exchangeId != null &&
        (arrivalTiming == 'late' || arrivalTiming == 'very_late')) {
      unawaited(
        _db.collection('riskEvents').add(<String, dynamic>{
          'type': 'late_exchange_checkin',
          'severity': arrivalTiming == 'very_late' ? 2 : 1,
          'linkedExchangeId': exchangeId,
          'linkedCheckInId': checkInId,
          'arrivalTiming': arrivalTiming,
          'userId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        }),
      );
    }

    if (exchangeId != null &&
        verificationStatus != ExchangeCheckinVerificationStatus.failed &&
        latitude != null &&
        longitude != null) {
      await ExchangeService.checkIn(
        caseId: caseId,
        exchangeId: exchangeId,
        actualLat: latitude,
        actualLng: longitude,
        logTimelineEvent: false,
      );
    }

    unawaited(CustodyRiskInsightsService.refresh(caseId));
    try {
      final authUidAfter = FirebaseAuth.instance.currentUser?.uid;
      final afterSnap = await userRef.get();
      final userAfter = afterSnap.data();
      if (kDebugMode) {
        debugPrint(
          '[ExchangeCheckin] after submit uid=$authUidAfter userDoc=$userAfter',
        );
      }
    } catch (_) {}

    return ExchangeCheckinSubmitResult(
      checkInId: checkInId,
      contentHash: hash,
      recordedAddress:
          resolvedAddress.isNotEmpty ? resolvedAddress : '—',
      deviceTimestamp: deviceTimestamp,
      arrivalTiming: arrivalTiming,
      minutesFromScheduled: minutesFromScheduled,
    );
  }
}
