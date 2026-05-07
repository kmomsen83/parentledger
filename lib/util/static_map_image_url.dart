import '../config/env.dart';

/// Google Static Maps preview URL (same API key as Places; enable Static Maps API in GCP).
String buildCheckInStaticMapUrl({
  required double lat,
  required double lng,
  int width = 640,
  int height = 320,
  int zoom = 15,
}) {
  if (googleApiKey.isEmpty) return '';
  final center = '$lat,$lng';
  final q = <String, String>{
    'center': center,
    'zoom': '$zoom',
    'size': '${width}x$height',
    'scale': '2',
    'maptype': 'roadmap',
    'markers': 'color:red|$center',
    'key': googleApiKey,
  };
  return Uri(
    scheme: 'https',
    host: 'maps.googleapis.com',
    path: '/maps/api/staticmap',
    queryParameters: q,
  ).toString();
}
