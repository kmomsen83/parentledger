import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geocoding/geocoding.dart';

import '../models/case_event.dart';
import '../models/case_ledger_write_result.dart';
import '../models/exchange_model.dart';
import 'event_logger_service.dart';
import 'exchange_service.dart';
import 'location_service.dart';

/// Foreground-only verified presence check-in → `case_events` ledger (`check_in`) and optional
/// photo metadata in `cases/{caseId}/check_in_enrichments/{ledgerEventId}` (ledger rows are immutable).
///
/// **Example — one tap:**
/// ```dart
/// final r = await CheckInService.recordPresence(caseId: caseId);
/// if (!r.ok) {
///   ScaffoldMessenger.of(context).showSnackBar(Text(r.errorMessage ?? 'Failed'));
///   return;
/// }
/// ```
///
/// **Example — with optional photo file after GPS (same call):**
/// ```dart
/// await CheckInService.recordPresence(
///   caseId: caseId,
///   localPhotoPath: picked?.path,
/// );
/// ```
class CheckInService {
  CheckInService._();

  static const Duration exchangeLinkWindow = Duration(hours: 2);

  static final _db = FirebaseFirestore.instance;

  /// Supplement for optional photo / extra fields without mutating `case_events`.
  static DocumentReference<Map<String, dynamic>> enrichmentDoc(
    String caseId,
    String ledgerEventId,
  ) =>
      _db
          .collection('cases')
          .doc(caseId)
          .collection('check_in_enrichments')
          .doc(ledgerEventId);

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchEnrichment(
    String caseId,
    String ledgerEventId,
  ) =>
      enrichmentDoc(caseId, ledgerEventId).snapshots();

  /// Queries custody exchanges with `scheduledTime` within ± [exchangeLinkWindow] of [at].
  static Future<String?> findLinkedExchangeId({
    required String caseId,
    required DateTime at,
  }) async {
    final start = at.subtract(exchangeLinkWindow);
    final end = at.add(exchangeLinkWindow);
    final snap = await ExchangeService.exchangesCol(caseId)
        .where('scheduledTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    if (snap.docs.isEmpty) return null;

    final candidates = snap.docs
        .map(ExchangeModel.fromDoc)
        .where((e) => e.status == 'scheduled' || e.status == 'completed')
        .toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final da = a.scheduledTime.difference(at).abs();
      final db = b.scheduledTime.difference(at).abs();
      return da.compareTo(db);
    });
    return candidates.first.id;
  }

  /// Best-effort reverse geocoding; never throws.
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final list = await placemarkFromCoordinates(lat, lng);
      if (list.isEmpty) return null;
      final p = list.first;
      final parts = <String?>[
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
        p.postalCode,
      ]
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isEmpty) {
        final n = p.name?.trim();
        return n != null && n.isNotEmpty ? n : null;
      }
      return parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  static Reference _photoRef(String caseId, String eventId, String fileName) {
    return FirebaseStorage.instance
        .ref()
        .child('cases')
        .child(caseId)
        .child('check_ins')
        .child(eventId)
        .child(fileName);
  }

  /// Uploads a local image and returns a download URL.
  static Future<String> uploadCheckInPhoto({
    required String caseId,
    required String ledgerEventId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw StateError('Photo file not found');
    }
    final safeName =
        'check_in_${DateTime.now().millisecondsSinceEpoch}.jpg'
            .replaceAll(RegExp(r'[/\\]'), '_');
    final ref = _photoRef(caseId, ledgerEventId, safeName);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  static Future<void> writeEnrichmentPhotoUrl({
    required String caseId,
    required String ledgerEventId,
    required String photoUrl,
  }) async {
    await enrichmentDoc(caseId, ledgerEventId).set(<String, dynamic>{
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Permission + one GPS read (via [LocationService.getExchangeLocation]), optional geocode,
  /// smart exchange link, ledger write. Optional photo uploads after the ledger id is known.
  static Future<CheckInRecordResult> recordPresence({
    required String caseId,
    bool reverseGeocode = true,
    String? localPhotoPath,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return CheckInRecordResult.failure('Not signed in');
    }
    final deviceTime = DateTime.now();

    final fix = await LocationService.getExchangeLocation();
    if (fix == null) {
      return CheckInRecordResult.failure(
        'Location unavailable. Enable location services and grant permission, then try again.',
      );
    }

    String? address;
    if (reverseGeocode) {
      address = await CheckInService.reverseGeocode(
        fix.latitude,
        fix.longitude,
      );
    }

    String? linkedId;
    try {
      linkedId = await findLinkedExchangeId(caseId: caseId, at: deviceTime);
    } catch (_) {
      linkedId = null;
    }

    final data = <String, dynamic>{
      'eventSubtype': 'check_in',
      'lat': fix.latitude,
      'lng': fix.longitude,
      'accuracy': fix.accuracyMeters,
      if (address != null && address.isNotEmpty) 'address': address,
      if (linkedId != null) 'linkedExchangeId': linkedId,
      'clientTimestamp': deviceTime.toUtc().toIso8601String(),
    };

    final CaseLedgerWriteResult ledger;
    try {
      ledger = await EventLoggerService.logCaseEventForActorWithResult(
        caseId: caseId,
        type: CaseEventTypes.checkIn,
        title: 'Location check-in',
        description: address ??
            '${fix.latitude.toStringAsFixed(5)}, ${fix.longitude.toStringAsFixed(5)}',
        actorId: user.uid,
        metadata: data,
      );
    } catch (e) {
      return CheckInRecordResult.failure('$e');
    }

    // Ledger row is immutable — failures below must not be reported as a failed check-in
    // or users retry and create duplicate `check_in` ledger events.
    String? enrichmentPhotoUrl;
    String? secondaryWarning;
    if (localPhotoPath != null && localPhotoPath.trim().isNotEmpty) {
      try {
        enrichmentPhotoUrl = await uploadCheckInPhoto(
          caseId: caseId,
          ledgerEventId: ledger.eventId,
          localPath: localPhotoPath.trim(),
        );
        await writeEnrichmentPhotoUrl(
          caseId: caseId,
          ledgerEventId: ledger.eventId,
          photoUrl: enrichmentPhotoUrl,
        );
      } catch (_) {
        secondaryWarning =
            'Location was saved, but the photo could not be attached. You can add a photo in the next step.';
      }
    }

    return CheckInRecordResult.ok(
      ledger: ledger,
      address: address,
      linkedExchangeId: linkedId,
      fix: fix,
      deviceTime: deviceTime,
      enrichmentPhotoUrl: enrichmentPhotoUrl,
      secondaryWarning: secondaryWarning,
    );
  }

  /// Call after [recordPresence] when the user adds a photo in a second step.
  static Future<void> attachPhotoAfterCheckIn({
    required String caseId,
    required String ledgerEventId,
    required String localPhotoPath,
  }) async {
    final url = await uploadCheckInPhoto(
      caseId: caseId,
      ledgerEventId: ledgerEventId,
      localPath: localPhotoPath,
    );
    await writeEnrichmentPhotoUrl(
      caseId: caseId,
      ledgerEventId: ledgerEventId,
      photoUrl: url,
    );
  }
}

class CheckInRecordResult {
  CheckInRecordResult._({
    required this.ok,
    this.errorMessage,
    this.ledger,
    this.address,
    this.linkedExchangeId,
    this.fix,
    this.deviceTime,
    this.enrichmentPhotoUrl,
    this.secondaryWarning,
  });

  factory CheckInRecordResult.ok({
    required CaseLedgerWriteResult ledger,
    required ExchangeLocationFix fix,
    required DateTime deviceTime,
    String? address,
    String? linkedExchangeId,
    String? enrichmentPhotoUrl,
    String? secondaryWarning,
  }) {
    return CheckInRecordResult._(
      ok: true,
      ledger: ledger,
      fix: fix,
      deviceTime: deviceTime,
      address: address,
      linkedExchangeId: linkedExchangeId,
      enrichmentPhotoUrl: enrichmentPhotoUrl,
      secondaryWarning: secondaryWarning,
    );
  }

  factory CheckInRecordResult.failure(String message) {
    return CheckInRecordResult._(
      ok: false,
      errorMessage: message,
    );
  }

  final bool ok;
  final String? errorMessage;
  final CaseLedgerWriteResult? ledger;
  final String? address;
  final String? linkedExchangeId;
  final ExchangeLocationFix? fix;
  final DateTime? deviceTime;
  final String? enrichmentPhotoUrl;

  /// When [ok] is true: optional user-visible hint (e.g. photo failed after ledger saved).
  final String? secondaryWarning;
}
