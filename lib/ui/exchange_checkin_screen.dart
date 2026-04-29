import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';
import '../models/exchange_checkin_record.dart';
import '../models/exchange_model.dart';
import '../services/exchange_checkin_service.dart';
import '../services/location_service.dart';
import '../util/device_info_helper.dart';
import '../util/exchange_maps_uri.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/trust_elements.dart';

import 'exchange_checkin_confirmation_screen.dart';

enum _Phase {
  /// No scheduled exchange — offer manual log.
  manualOffer,

  /// Scheduled: show details + proximity result.
  scheduledGate,

  /// Manual path: brief before GPS.
  manualPrelude,

  /// Resolving GPS (full screen).
  locating,

  /// Live check-in (timestamp, coords, photo, note).
  activeCheckIn,
}

enum _Proximity { idle, loading, noFix, denied, far, near }

/// Court-oriented exchange check-in with proximity gate, active session, and confirmation.
class ExchangeCheckinScreen extends StatefulWidget {
  const ExchangeCheckinScreen({
    super.key,
    required this.caseId,
    this.scheduledExchange,
  });

  final String caseId;
  final ExchangeModel? scheduledExchange;

  @override
  State<ExchangeCheckinScreen> createState() => _ExchangeCheckinScreenState();
}

class _ExchangeCheckinScreenState extends State<ExchangeCheckinScreen> {
  /// Outer bound of “at exchange location” (meters).
  static const double _proximityMaxMeters = 300;

  _Phase _phase = _Phase.scheduledGate;
  _Proximity _proximity = _Proximity.idle;

  String? _childName;
  ExchangeLocationFix? _sessionPosition;
  double? _distanceMeters;
  ExchangeCheckinVerificationStatus? _verification;

  final TextEditingController _noteController = TextEditingController();
  XFile? _photo;
  bool _submitting = false;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  ExchangeModel? get _ex => widget.scheduledExchange;
  bool get _isManual => _ex == null;

  @override
  void initState() {
    super.initState();
    if (_isManual) {
      _phase = _Phase.manualOffer;
      _proximity = _Proximity.idle;
    } else {
      _phase = _Phase.scheduledGate;
      _proximity = _Proximity.loading;
      _loadChildName();
      _checkAutoMissed();
      _runScheduledGateLocation();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _loadChildName() async {
    final ex = _ex;
    if (ex == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('cases')
          .doc(widget.caseId)
          .collection('children')
          .doc(ex.childId)
          .get();
      if (!mounted) return;
      final n = doc.data()?['name']?.toString();
      setState(() => _childName = n ?? 'Child');
    } catch (_) {
      if (mounted) setState(() => _childName = 'Child');
    }
  }

  Future<void> _checkAutoMissed() async {
    final ex = _ex;
    if (ex == null) return;

    final now = DateTime.now();
    if (now.isBefore(ex.scheduledTime.add(const Duration(minutes: 30)))) {
      return;
    }

    final db = FirebaseFirestore.instance;
    final existing = await db
        .collection('riskEvents')
        .where('linkedExchangeId', isEqualTo: ex.id)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await db.collection('riskEvents').add({
      'type': 'missed_exchange',
      'severity': 2,
      'linkedExchangeId': ex.id,
      'caseId': widget.caseId,
      'userId': uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _runScheduledGateLocation() async {
    if (_isManual) return;

    final p = await LocationService.getExchangeLocation();
    if (!mounted) return;

    if (p == null) {
      final perm = await Geolocator.checkPermission();
      setState(() {
        _proximity = perm == LocationPermission.deniedForever
            ? _Proximity.denied
            : _Proximity.noFix;
        _sessionPosition = null;
        _distanceMeters = null;
      });
      return;
    }

    final ex = _ex!;
    final dist = Geolocator.distanceBetween(
      p.latitude,
      p.longitude,
      ex.lat,
      ex.lng,
    );

    setState(() {
      _sessionPosition = p;
      _distanceMeters = dist;
      _proximity =
          dist <= _proximityMaxMeters ? _Proximity.near : _Proximity.far;
    });
  }

  Widget _trustHelpers() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HelperText(
          text: 'Each check-in records time and optional location for your records.',
          icon: Icons.lock_clock_outlined,
        ),
        SizedBox(height: 6),
        HelperText(
          text: 'Location is securely logged when enabled.',
          icon: Icons.location_on_outlined,
        ),
      ],
    );
  }

  Future<void> _openNavigationToExchange() async {
    final ex = _ex;
    if (ex == null) return;
    final uri = exchangeMapsUri(ex.lat, ex.lng);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _startActiveCheckIn() {
    if (_sessionPosition == null && !_isManual) return;
    _startClock();
    setState(() {
      _phase = _Phase.activeCheckIn;
      if (_isManual) {
        _verification = _sessionPosition != null
            ? ExchangeCheckinVerificationStatus.verified
            : ExchangeCheckinVerificationStatus.failed;
      } else {
        final dist = _distanceMeters ?? double.infinity;
        _verification = dist <= _proximityMaxMeters
            ? ExchangeCheckinVerificationStatus.verified
            : ExchangeCheckinVerificationStatus.partial;
      }
    });
  }

  Future<void> _manualBegin() async {
    setState(() => _phase = _Phase.manualPrelude);
  }

  Future<void> _manualRunGps() async {
    setState(() => _phase = _Phase.locating);
    final p = await LocationService.getExchangeLocation();
    if (!mounted) return;
    setState(() {
      _sessionPosition = p;
      _verification = p != null
          ? ExchangeCheckinVerificationStatus.verified
          : ExchangeCheckinVerificationStatus.failed;
      _distanceMeters = null;
      _phase = _Phase.activeCheckIn;
    });
    _startClock();
  }

  Future<void> _refreshSessionGps() async {
    final p = await LocationService.getExchangeLocation();
    if (!mounted || p == null) return;
    setState(() {
      _sessionPosition = p;
      if (_ex != null) {
        _distanceMeters = Geolocator.distanceBetween(
          p.latitude,
          p.longitude,
          _ex!.lat,
          _ex!.lng,
        );
        _verification = _distanceMeters! <= _proximityMaxMeters
            ? ExchangeCheckinVerificationStatus.verified
            : ExchangeCheckinVerificationStatus.partial;
      }
    });
  }

  Future<void> _pickPhoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.camera);
    if (!mounted) return;
    if (img != null) setState(() => _photo = img);
  }

  String _handoffTypeForSubmit() {
    final ex = _ex;
    if (ex == null) return 'manual';
    final t = ex.type.toLowerCase();
    if (t == 'pickup' || t == 'dropoff') return t;
    return 'exchange';
  }

  Future<void> _completeCheckIn() async {
    if (_submitting || _verification == null) return;
    final authBefore = FirebaseAuth.instance.currentUser;
    final uidBefore = authBefore?.uid;
    if (uidBefore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('notSignedInPleaseSign'))),
      );
      return;
    }
    if (kDebugMode) {
      debugPrint('[ExchangeCheckin] submit start uid=$uidBefore');
    }

    setState(() => _submitting = true);
    final deviceTs = DateTime.now();
    final ex = _ex;

    try {
      final result = await ExchangeCheckinService.submit(
        caseId: widget.caseId,
        exchangeId: ex?.id,
        verificationStatus: _verification!,
        latitude: _sessionPosition?.latitude,
        longitude: _sessionPosition?.longitude,
        locationAccuracy: _sessionPosition?.accuracyMeters,
        deviceTimestamp: deviceTs,
        photoLocalPath: _photo?.path,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        handoffType: _handoffTypeForSubmit(),
        distanceFromExpectedMeters: _distanceMeters,
        expectedLocationName: ex?.locationName,
        recordedAddress: ex?.navigateAddress,
        scheduledTime: ex?.scheduledTime,
        deviceInfo: collectDeviceInfoForAudit(),
      );
      final uidAfter = FirebaseAuth.instance.currentUser?.uid;
      if (kDebugMode) {
        debugPrint('[ExchangeCheckin] submit end uid=$uidAfter');
      }
      if (uidAfter == null || uidAfter != uidBefore) {
        throw StateError('Authentication session changed during check-in.');
      }

      if (!mounted) return;
      _clockTimer?.cancel();
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExchangeCheckinConfirmationScreen(
            caseId: widget.caseId,
            exchangeId: ex?.id,
            result: result,
            latitude: _sessionPosition?.latitude,
            longitude: _sessionPosition?.longitude,
            accuracyMeters: _sessionPosition?.accuracyMeters,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save check-in: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _typeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'pickup':
        return 'Pickup';
      case 'dropoff':
        return 'Drop-off';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayFmt = DateFormat.yMMMd();
    final timeFmt = DateFormat.jm();
    final fullFmt = DateFormat.yMMMd().add_jm();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('exchangeCheckin')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: switch (_phase) {
        _Phase.manualOffer => _buildManualOffer(context),
        _Phase.scheduledGate =>
          _buildScheduledGate(context, dayFmt, timeFmt),
        _Phase.manualPrelude => _buildManualPrelude(context),
        _Phase.locating => _buildLocating(context),
        _Phase.activeCheckIn =>
          _buildActiveCheckIn(context, fullFmt),
      },
    );
  }

  Widget _buildManualOffer(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: PLDesign.gradientCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No scheduled exchange', style: PLDesign.heroTitle),
              const SizedBox(height: 12),
              Text(
                'You can still log a time-stamped custody exchange with GPS, '
                'optional photo, and note for your case file.',
                style: PLDesign.body.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _trustHelpers(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _manualBegin,
          child: Text(context.tTone('logManualCheckin')),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tTone('cancel')),
        ),
      ],
    );
  }

  Widget _buildScheduledGate(
    BuildContext context,
    DateFormat dayFmt,
    DateFormat timeFmt,
  ) {
    final ex = _ex!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Upcoming exchange', style: PLDesign.caption),
        const SizedBox(height: 8),
        Text('Review details', style: PLDesign.heroTitle.copyWith(fontSize: 24)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: PLDesign.gradientCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(Icons.child_care_outlined, 'Child',
                  _childName ?? '…'),
              const Divider(height: 28, color: PLDesign.border),
              _detailRow(
                Icons.swap_horiz_rounded,
                'Type',
                _typeLabel(ex.type),
              ),
              const Divider(height: 28, color: PLDesign.border),
              _detailRow(
                Icons.schedule_rounded,
                'Time',
                '${dayFmt.format(ex.scheduledTime)} · ${timeFmt.format(ex.scheduledTime)}',
              ),
              const Divider(height: 28, color: PLDesign.border),
              _detailRow(
                Icons.place_outlined,
                'Location',
                ex.navigateAddress,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _trustHelpers(),
        const SizedBox(height: 14),
        if (_proximity == _Proximity.loading)
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(context.tTone('detectingYourLocation')),
                ],
              ),
            ),
          )
        else if (_proximity == _Proximity.denied ||
            _proximity == _Proximity.noFix)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: PLDesign.danger.withValues(alpha: 0.1),
              borderRadius: PLDesign.r16,
              border: Border.all(
                color: PLDesign.danger.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location unavailable',
                  style: PLDesign.sectionTitle.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 8),
                Text(
                  _proximity == _Proximity.denied
                      ? 'Enable location permission in system settings to continue.'
                      : 'Could not read GPS. Move outdoors and try again.',
                  style: PLDesign.caption.copyWith(height: 1.35),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _proximity = _Proximity.loading);
                    _runScheduledGateLocation();
                  },
                  child: Text(context.tTone('tryAgain')),
                ),
              ],
            ),
          )
        else if (_proximity == _Proximity.far)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PLDesign.warning.withValues(alpha: 0.1),
              borderRadius: PLDesign.r16,
              border: Border.all(
                color: PLDesign.warning.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: PLDesign.warning, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You are not at the exchange location',
                        style: PLDesign.sectionTitle.copyWith(fontSize: 17),
                      ),
                    ),
                  ],
                ),
                if (_distanceMeters != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'About ${_distanceMeters!.round()} m from the scheduled coordinates '
                    '(within ${_proximityMaxMeters.round()} m is required to start check-in).',
                    style: PLDesign.caption.copyWith(height: 1.4),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _openNavigationToExchange,
                  icon: const Icon(Icons.navigation_rounded),
                  label: Text(context.tTone('openNavigation')),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _proximity = _Proximity.loading);
                    _runScheduledGateLocation();
                  },
                  child: Text(context.tTone('refreshLocation')),
                ),
              ],
            ),
          )
        else if (_proximity == _Proximity.near)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PLDesign.success.withValues(alpha: 0.1),
              borderRadius: PLDesign.r16,
              border: Border.all(
                color: PLDesign.success.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.where_to_vote_rounded,
                        color: PLDesign.success, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You are at the exchange location',
                        style: PLDesign.sectionTitle.copyWith(fontSize: 17),
                      ),
                    ),
                  ],
                ),
                if (_distanceMeters != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Within ${_distanceMeters!.round()} m of scheduled coordinates.',
                    style: PLDesign.caption.copyWith(height: 1.35),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _startActiveCheckIn,
                  child: Text(context.tTone('startCheckin')),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: PLDesign.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: PLDesign.caption),
              const SizedBox(height: 4),
              Text(
                value,
                style: PLDesign.body.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualPrelude(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Manual check-in', style: PLDesign.heroTitle.copyWith(fontSize: 24)),
        const SizedBox(height: 12),
        Text(
          'We will capture GPS, optional photo, and note. The entry is permanent.',
          style: PLDesign.body.copyWith(height: 1.4),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _manualRunGps,
          child: Text(context.tTone('continueLabel')),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _phase = _Phase.manualOffer),
          child: Text(context.tTone('back')),
        ),
      ],
    );
  }

  Widget _buildLocating(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Capturing GPS…', style: PLDesign.sectionTitle),
            const SizedBox(height: 8),
            Text(
              'Hold steady for a few seconds.',
              textAlign: TextAlign.center,
              style: PLDesign.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCheckIn(
    BuildContext context,
    DateFormat fullFmt,
  ) {
    final pos = _sessionPosition;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: PLDesign.gradientCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active check-in', style: PLDesign.sectionTitle),
              const SizedBox(height: 12),
              Text('Live time', style: PLDesign.caption),
              Text(
                fullFmt.format(_now),
                style: PLDesign.heroTitle.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 16),
              Text('GPS coordinates', style: PLDesign.caption),
              Text(
                pos != null
                    ? '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}'
                    : '—',
                style: PLDesign.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pos != null && pos.accuracyMeters != null
                    ? 'Accuracy ±${pos.accuracyMeters!.toStringAsFixed(0)} m'
                    : pos != null
                        ? 'Accuracy unavailable'
                        : 'No fix — check-in may be marked incomplete',
                style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _trustHelpers(),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ClipRRect(
            borderRadius: PLDesign.r16,
            child: pos == null
                ? Container(
                    color: PLDesign.card,
                    alignment: Alignment.center,
                    child: Text(
                      'No map preview',
                      style: PLDesign.caption,
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: pos.latLng,
                      zoom: 16,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('here'),
                        position: pos.latLng,
                      ),
                      if (_ex != null)
                        Marker(
                          markerId: const MarkerId('expected'),
                          position: LatLng(_ex!.lat, _ex!.lng),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ),
                        ),
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _refreshSessionGps,
          icon: const Icon(Icons.my_location_rounded, size: 20),
          label: Text(context.tTone('refreshGps')),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(_photo == null ? 'Add photo (camera)' : 'Replace photo'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteController,
          maxLines: 3,
          style: PLDesign.body,
          decoration: InputDecoration(
            labelText: 'Optional note',
            labelStyle: PLDesign.caption,
            alignLabelWithHint: true,
            filled: true,
            fillColor: PLDesign.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _submitting ? null : _completeCheckIn,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
          ),
          child: _submitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tTone('completeCheckin')),
        ),
        const SizedBox(height: 12),
        Text(
          'Submitting creates an immutable record with server time, device context, and integrity hash.',
          textAlign: TextAlign.center,
          style: PLDesign.caption.copyWith(
            color: PLDesign.textMuted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
