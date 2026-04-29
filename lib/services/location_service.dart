import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';

/// GPS snapshot for exchange check-in (maps-friendly point + device accuracy).
class ExchangeLocationFix {
  const ExchangeLocationFix({
    required this.latLng,
    this.accuracyMeters,
  });

  final LatLng latLng;
  final double? accuracyMeters;

  double get latitude => latLng.latitude;
  double get longitude => latLng.longitude;
}

/// Single prediction from Places Autocomplete.
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
  });

  final String placeId;
  final String description;
}

/// Resolved place with coordinates (from Place Details).
class ResolvedPlace {
  const ResolvedPlace({
    required this.placeId,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.name,
  });

  final String placeId;
  final String formattedAddress;
  final String? name;
  final double lat;
  final double lng;
}

/// Outcome of autocomplete / details calls (no raw Google error strings to UI).
enum PlacesClientStatus {
  ok,
  missingKey,
  networkError,
  invalidResponse,
  deniedOrInvalidKey,
  zeroResults,
}

class PlacesAutocompleteResult {
  const PlacesAutocompleteResult({
    required this.status,
    this.predictions = const [],
  });

  final PlacesClientStatus status;
  final List<PlacePrediction> predictions;
}

class PlacesDetailsResult {
  const PlacesDetailsResult({
    required this.status,
    this.place,
  });

  final PlacesClientStatus status;
  final ResolvedPlace? place;
}

/// Places HTTP APIs + device GPS for check-in.
abstract final class LocationService {
  /// Requests permission, reads current GPS, returns coordinates (or null if denied / error).
  static Future<ExchangeLocationFix?> getExchangeLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return ExchangeLocationFix(
        latLng: LatLng(position.latitude, position.longitude),
        accuracyMeters: position.accuracy,
      );
    } catch (_) {
      return null;
    }
  }

  static const _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  static bool get isPlacesConfigured => googleApiKey.isNotEmpty;

  static Future<PlacesAutocompleteResult> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const PlacesAutocompleteResult(
        status: PlacesClientStatus.ok,
        predictions: [],
      );
    }
    if (!isPlacesConfigured) {
      return const PlacesAutocompleteResult(
        status: PlacesClientStatus.missingKey,
      );
    }

    final uri = Uri.parse(_autocompleteUrl).replace(queryParameters: {
      'input': trimmed,
      'key': googleApiKey,
      'types': 'address',
    });

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        return const PlacesAutocompleteResult(
          status: PlacesClientStatus.networkError,
        );
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>?;
      if (map == null) {
        return const PlacesAutocompleteResult(
          status: PlacesClientStatus.invalidResponse,
        );
      }

      final status = map['status'] as String? ?? '';
      if (status == 'REQUEST_DENIED' ||
          status == 'INVALID_REQUEST' ||
          status == 'OVER_QUERY_LIMIT') {
        return const PlacesAutocompleteResult(
          status: PlacesClientStatus.deniedOrInvalidKey,
        );
      }
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        return const PlacesAutocompleteResult(
          status: PlacesClientStatus.invalidResponse,
        );
      }

      final preds = <PlacePrediction>[];
      final raw = map['predictions'];
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map<String, dynamic>) continue;
          final id = item['place_id'] as String?;
          final desc = item['description'] as String?;
          if (id == null || id.isEmpty || desc == null) continue;
          preds.add(PlacePrediction(placeId: id, description: desc));
        }
      }

      return PlacesAutocompleteResult(
        status: status == 'ZERO_RESULTS'
            ? PlacesClientStatus.zeroResults
            : PlacesClientStatus.ok,
        predictions: preds,
      );
    } catch (_) {
      return const PlacesAutocompleteResult(
        status: PlacesClientStatus.networkError,
      );
    }
  }

  static Future<PlacesDetailsResult> getPlaceDetails(String placeId) async {
    final id = placeId.trim();
    if (id.isEmpty) {
      return const PlacesDetailsResult(status: PlacesClientStatus.invalidResponse);
    }
    if (!isPlacesConfigured) {
      return const PlacesDetailsResult(status: PlacesClientStatus.missingKey);
    }

    final uri = Uri.parse(_detailsUrl).replace(queryParameters: {
      'place_id': id,
      'fields': 'geometry,formatted_address,name,place_id',
      'key': googleApiKey,
    });

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        return const PlacesDetailsResult(status: PlacesClientStatus.networkError);
      }
      final map = jsonDecode(res.body) as Map<String, dynamic>?;
      if (map == null) {
        return const PlacesDetailsResult(status: PlacesClientStatus.invalidResponse);
      }

      final status = map['status'] as String? ?? '';
      if (status == 'REQUEST_DENIED' ||
          status == 'INVALID_REQUEST' ||
          status == 'NOT_FOUND') {
        return const PlacesDetailsResult(
          status: PlacesClientStatus.deniedOrInvalidKey,
        );
      }
      if (status != 'OK') {
        return const PlacesDetailsResult(status: PlacesClientStatus.invalidResponse);
      }

      final result = map['result'] as Map<String, dynamic>?;
      if (result == null) {
        return const PlacesDetailsResult(status: PlacesClientStatus.invalidResponse);
      }

      final geometry = result['geometry'] as Map<String, dynamic>?;
      final loc = geometry?['location'] as Map<String, dynamic>?;
      final lat = (loc?['lat'] as num?)?.toDouble();
      final lng = (loc?['lng'] as num?)?.toDouble();
      final formatted = result['formatted_address'] as String? ?? '';
      final name = result['name'] as String?;
      final pid = result['place_id'] as String? ?? id;

      if (lat == null || lng == null || formatted.isEmpty) {
        return const PlacesDetailsResult(status: PlacesClientStatus.invalidResponse);
      }

      return PlacesDetailsResult(
        status: PlacesClientStatus.ok,
        place: ResolvedPlace(
          placeId: pid,
          formattedAddress: formatted,
          name: name,
          lat: lat,
          lng: lng,
        ),
      );
    } catch (_) {
      return const PlacesDetailsResult(status: PlacesClientStatus.networkError);
    }
  }
}
