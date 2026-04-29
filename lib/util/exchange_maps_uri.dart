import 'package:flutter/foundation.dart';

/// Native maps deep link for an exchange coordinate (iOS → Apple Maps, else Google).
Uri exchangeMapsUri(double lat, double lng) {
  if (kIsWeb) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return Uri.parse('http://maps.apple.com/?ll=$lat,$lng');
  }
  return Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
  );
}
