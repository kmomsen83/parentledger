import 'package:flutter/foundation.dart';

/// Default **public** Maps/Places key (restrict in Google Cloud Console by app/package).
/// Override: `--dart-define=GOOGLE_PLACES_API_KEY=...`
const String _defaultGoogleMapsApiKey =
    'AIzaSyCpl7vDdAwrJMT7cRY9ccHH1xzl0uCeI9k';

String get googleApiKey {
  const k = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
  if (k.isNotEmpty) {
    return k;
  }
  return _defaultGoogleMapsApiKey;
}

/// Throws if Places validation is invoked without a key (default or define).
void validateApiKey() {
  if (googleApiKey.isEmpty) {
    throw Exception(
      'Missing GOOGLE_PLACES_API_KEY. Build with --dart-define=GOOGLE_PLACES_API_KEY=...',
    );
  }
}

/// Debug-only: whether a Places key was compiled in (does not log the key).
void logGoogleApiKeyDebug() {
  if (kDebugMode) {
    debugPrint(
      'Google Places API key: ${googleApiKey.isNotEmpty ? "present" : "missing"}',
    );
  }
}
