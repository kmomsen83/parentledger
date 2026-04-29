import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/exchange_service.dart';
import 'widgets/trust_elements.dart';
import '../services/location_service.dart';
import 'exchange_scheduled_confirmation_screen.dart';

/// Premium schedule flow: structured sections, Places-backed location, confirmation.
class CreateExchangeScreen extends StatefulWidget {
  const CreateExchangeScreen({super.key});

  @override
  State<CreateExchangeScreen> createState() => _CreateExchangeScreenState();
}

class _CreateExchangeScreenState extends State<CreateExchangeScreen> {
  String type = 'pickup';

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  String address = '';
  String locationName = '';
  double? lat;
  double? lng;
  String? placeId;
  bool locationVerified = false;

  String? selectedChildId;
  List<Map<String, dynamic>> children = [];
  bool loadingChildren = true;

  bool saving = false;

  final TextEditingController _locationController = TextEditingController();

  Timer? _placeSearchDebounce;
  List<PlacePrediction> _placeSuggestions = [];
  bool _placesLoading = false;
  /// When false, uses Places autocomplete (if configured). When true, manual + geocoding.
  late bool _manualLocationMode;
  bool _manualGeocoding = false;
  String _lastResolvedAddressSnapshot = '';

  @override
  void initState() {
    super.initState();
    _manualLocationMode = !LocationService.isPlacesConfigured;
    loadChildren();
  }

  @override
  void dispose() {
    _placeSearchDebounce?.cancel();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> loadChildren() async {
    final caseId = context.read<CaseContext>().caseId;
    if (caseId == null) {
      if (mounted) setState(() => loadingChildren = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('cases')
          .doc(caseId)
          .collection('children')
          .get();

      final list = snap.docs
          .map((d) => <String, dynamic>{
                'id': d.id,
                'name': d['name'] ?? 'Child',
              })
          .toList();

      if (!mounted) return;
      setState(() {
        children = list;
        if (children.length == 1) {
          selectedChildId = children.first['id'] as String;
        }
        loadingChildren = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        children = [];
        loadingChildren = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load case children right now. Check connection and try again.',
          ),
        ),
      );
    }
  }

  void _schedulePlaceSearch(String value) {
    _placeSearchDebounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() => _placeSuggestions = []);
      return;
    }
    _placeSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      _runPlaceSearch(q);
    });
  }

  Future<void> _runPlaceSearch(String q) async {
    if (!mounted || _manualLocationMode) return;
    setState(() => _placesLoading = true);
    PlacesAutocompleteResult result;
    try {
      result = await LocationService.searchPlaces(q);
    } catch (_) {
      result = const PlacesAutocompleteResult(
        status: PlacesClientStatus.networkError,
      );
    }
    if (!mounted) return;
    setState(() => _placesLoading = false);

    switch (result.status) {
      case PlacesClientStatus.deniedOrInvalidKey:
      case PlacesClientStatus.networkError:
      case PlacesClientStatus.invalidResponse:
        setState(() {
          _placeSuggestions = [];
          _manualLocationMode = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location search is unavailable. Enter your address manually.',
              ),
            ),
          );
        }
        return;
      case PlacesClientStatus.missingKey:
        setState(() {
          _manualLocationMode = true;
          _placeSuggestions = [];
        });
        return;
      case PlacesClientStatus.zeroResults:
      case PlacesClientStatus.ok:
        setState(() => _placeSuggestions = result.predictions);
    }
  }

  void _applyResolvedPlace(ResolvedPlace p) {
    setState(() {
      address = p.formattedAddress;
      locationName = (p.name != null && p.name!.trim().isNotEmpty)
          ? p.name!.trim()
          : p.formattedAddress;
      lat = p.lat;
      lng = p.lng;
      placeId = p.placeId;
      locationVerified = true;
      _placeSuggestions = [];
      _locationController.text = p.formattedAddress;
      _lastResolvedAddressSnapshot = p.formattedAddress.trim();
    });
  }

  Future<void> _onSelectPrediction(PlacePrediction p) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _placesLoading = true;
      _placeSuggestions = [];
    });
    final result = await LocationService.getPlaceDetails(p.placeId);
    if (!mounted) return;
    setState(() => _placesLoading = false);
    if (result.status != PlacesClientStatus.ok || result.place == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not load that place. Try again or enter the address manually.',
            ),
          ),
        );
      }
      setState(() => _manualLocationMode = true);
      return;
    }
    _applyResolvedPlace(result.place!);
  }

  Future<void> _verifyManualAddress() async {
    final text = _locationController.text.trim();
    if (text.isEmpty) return;
    setState(() => _manualGeocoding = true);
    try {
      final locations = await locationFromAddress(text);
      if (!mounted) return;
      if (locations.isEmpty) {
        throw Exception('empty');
      }
      final loc = locations.first;
      setState(() {
        address = text;
        locationName = text;
        lat = loc.latitude;
        lng = loc.longitude;
        placeId = null;
        locationVerified = true;
        _lastResolvedAddressSnapshot = text;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tTone('addressVerifiedForThisExchange'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not verify that address. Try a fuller street address.',
            ),
          ),
        );
      }
      setState(() {
        locationVerified = false;
        lat = null;
        lng = null;
        placeId = null;
      });
    } finally {
      if (mounted) setState(() => _manualGeocoding = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t != null) setState(() => selectedTime = t);
  }

  Future<void> _submit() async {
    if (saving) return;

    final caseId = context.read<CaseContext>().caseId;
    if (caseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tTone('caseNotReadyFinishWorkspace'))),
      );
      return;
    }
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tTone('addAChildToYour')),
        ),
      );
      return;
    }
    if (selectedDate == null ||
        selectedTime == null ||
        selectedChildId == null ||
        !locationVerified ||
        lat == null ||
        lng == null ||
        address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tTone('completeAllSectionsIncludingA')),
        ),
      );
      return;
    }

    setState(() => saving = true);

    final scheduled = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    try {
      final exchangeId = await ExchangeService.createExchange(
        caseId: caseId,
        childId: selectedChildId!,
        scheduledTime: scheduled,
        type: type,
        locationName: locationName.isNotEmpty ? locationName : address,
        address: address,
        placeId: placeId,
        lat: lat!,
        lng: lng!,
      );

      if (!mounted) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExchangeScheduledConfirmationScreen(
            caseId: caseId,
            exchangeId: exchangeId,
            scheduledTime: scheduled,
            locationLabel: address,
            lat: lat!,
            lng: lng!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not schedule: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _sectionHeader(String title, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: PLDesign.sectionTitle),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint,
            style: PLDesign.caption.copyWith(
              color: PLDesign.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: PLDesign.gradientCard.copyWith(
        borderRadius: PLDesign.r16,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd();
    final placesConfigured = LocationService.isPlacesConfigured;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('scheduleExchange')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            'Structured for your case file',
            style: PLDesign.caption.copyWith(
              color: PLDesign.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // 1. Type
          _sectionHeader('1. Exchange type'),
          const SizedBox(height: 12),
          _sectionCard(
            child: Row(
              children: [
                Expanded(
                  child: _typeChip(
                    label: 'Pickup',
                    value: 'pickup',
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _typeChip(
                    label: 'Drop-off',
                    value: 'dropoff',
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // 2. Child
          _sectionHeader(
            '2. Child',
            hint: 'Who is this exchange for?',
          ),
          const SizedBox(height: 12),
          _sectionCard(
            child: loadingChildren
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : children.isEmpty
                    ? Text(
                        'No children on this case yet. Add a child in workspace setup.',
                        style: PLDesign.body.copyWith(height: 1.35),
                      )
                    : children.length == 1
                        ? Row(
                            children: [
                              Icon(Icons.child_care_rounded,
                                  color: PLDesign.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  children.first['name'] as String? ?? 'Child',
                                  style: PLDesign.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: selectedChildId,
                            dropdownColor: PLDesign.surface,
                            style: PLDesign.body,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: PLDesign.card,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: PLDesign.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: PLDesign.border),
                              ),
                              hintText: 'Select child',
                              hintStyle: PLDesign.caption,
                            ),
                            items: children.map((c) {
                              return DropdownMenuItem<String>(
                                value: c['id'] as String,
                                child: Text(c['name'] as String? ?? 'Child'),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => selectedChildId = v),
                          ),
          ),

          const SizedBox(height: 28),

          // 3. Date & time
          _sectionHeader(
            '3. Date & time',
            hint: 'When does the exchange take place?',
          ),
          const SizedBox(height: 12),
          _sectionCard(
            child: Column(
              children: [
                _dateTimeRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: selectedDate == null
                      ? 'Choose date'
                      : dateFmt.format(selectedDate!),
                  onTap: _pickDate,
                ),
                Divider(height: 24, color: PLDesign.border.withValues(alpha: 0.6)),
                _dateTimeRow(
                  icon: Icons.schedule_rounded,
                  label: 'Time',
                  value: selectedTime == null
                      ? 'Choose time'
                      : selectedTime!.format(context),
                  onTap: _pickTime,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // 4. Location
          _sectionHeader(
            '4. Location',
            hint:
                'Search and select an address. Coordinates are stored for verification and navigation.',
          ),
          const SizedBox(height: 12),
          if (!placesConfigured)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: PLDesign.warning.withValues(alpha: 0.12),
                borderRadius: PLDesign.r16,
                border: Border.all(
                  color: PLDesign.warning.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                'Google Places is not configured. Build with:\n'
                'flutter run --dart-define=GOOGLE_PLACES_API_KEY=your_key\n\n'
                'You can still enter an address manually below and verify it.',
                style: PLDesign.caption.copyWith(height: 1.4),
              ),
            ),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _locationController,
                  style: PLDesign.body.copyWith(color: PLDesign.textPrimary),
                  onChanged: (v) {
                    if (locationVerified &&
                        v.trim() != _lastResolvedAddressSnapshot) {
                      setState(() {
                        locationVerified = false;
                        lat = null;
                        lng = null;
                        placeId = null;
                      });
                    }
                    if (!placesConfigured || _manualLocationMode) {
                      setState(() => _placeSuggestions = []);
                    } else {
                      _schedulePlaceSearch(v);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: _manualLocationMode || !placesConfigured
                        ? 'Enter street address'
                        : 'Search address or place',
                    hintStyle: PLDesign.caption,
                    filled: true,
                    fillColor: PLDesign.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: PLDesign.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: PLDesign.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: PLDesign.primary, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    prefixIcon: Icon(Icons.place_outlined,
                        color: PLDesign.primary, size: 22),
                  ),
                ),
                if (_placesLoading && !_manualLocationMode && placesConfigured)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                if (!_manualLocationMode &&
                    placesConfigured &&
                    _placeSuggestions.isNotEmpty)
                  Material(
                    color: PLDesign.surface,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _placeSuggestions.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: PLDesign.border),
                      itemBuilder: (context, i) {
                        final p = _placeSuggestions[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            p.description,
                            style: PLDesign.body.copyWith(fontSize: 14),
                          ),
                          onTap: () => _onSelectPrediction(p),
                        );
                      },
                    ),
                  ),
                if (placesConfigured && !_manualLocationMode) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _manualLocationMode = true;
                          _placeSuggestions = [];
                        });
                      },
                      child: Text(context.tTone('enterAddressManually')),
                    ),
                  ),
                ],
                if (placesConfigured && _manualLocationMode) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _manualLocationMode = false;
                          locationVerified = false;
                          lat = null;
                          lng = null;
                          placeId = null;
                          _lastResolvedAddressSnapshot = '';
                        });
                      },
                      child: Text(context.tTone('useAddressSearch')),
                    ),
                  ),
                ],
                if (_manualLocationMode || !placesConfigured) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed:
                          _manualGeocoding ? null : _verifyManualAddress,
                      child: _manualGeocoding
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.tTone('verifyAddress')),
                    ),
                  ),
                ],
                if (locationVerified) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: PLDesign.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: PLDesign.success.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_outlined,
                            color: PLDesign.success, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Location verified for legal record',
                            style: PLDesign.body.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: PLDesign.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (placeId != null && placeId!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Place ID captured',
                      style: PLDesign.caption.copyWith(
                        color: PLDesign.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'This will be recorded in your case timeline',
            textAlign: TextAlign.center,
            style: PLDesign.caption.copyWith(
              color: PLDesign.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          const HelperText(
            text: 'Each check-in records time and optional location for your records.',
            icon: Icons.lock_clock_outlined,
          ),
          const SizedBox(height: 6),
          const HelperText(
            text: 'Location is securely logged when enabled.',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: (saving ||
                    children.isEmpty ||
                    !locationVerified ||
                    lat == null ||
                    lng == null)
                ? null
                : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            child: saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tTone('scheduleExchange')),
          ),
        ],
      ),
    );
  }

  Widget _typeChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final active = type == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => type = value),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? PLDesign.primary : PLDesign.border,
              width: active ? 1.5 : 1,
            ),
            color: active
                ? PLDesign.primary.withValues(alpha: 0.14)
                : PLDesign.card.withValues(alpha: 0.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? PLDesign.primary : PLDesign.textMuted),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: active ? PLDesign.textPrimary : PLDesign.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTimeRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: PLDesign.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: PLDesign.caption),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: PLDesign.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: PLDesign.textMuted),
          ],
        ),
      ),
    );
  }
}
