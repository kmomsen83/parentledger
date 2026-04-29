import 'env.dart';

/// Build with: `flutter run --dart-define=GOOGLE_PLACES_API_KEY=your_key`
///
/// Prefer importing [googleApiKey] from [env.dart] in new code.
abstract final class GoogleMapsConfig {
  static String get placesApiKey => googleApiKey;

  static bool get hasPlacesApiKey => googleApiKey.isNotEmpty;
}
