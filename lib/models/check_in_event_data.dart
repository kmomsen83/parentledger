import '../util/static_map_image_url.dart';
import 'timeline_event_model.dart';

/// Payload stored in `case_events` `data` / `metadata` for [CaseEventTypes.checkIn].
class CheckInEventData {
  const CheckInEventData({
    this.lat,
    this.lng,
    this.accuracyMeters,
    this.address,
    this.linkedExchangeId,
    this.photoUrl,
    this.clientTimestampIso,
  });

  final double? lat;
  final double? lng;
  final double? accuracyMeters;
  final String? address;
  final String? linkedExchangeId;
  final String? photoUrl;
  final String? clientTimestampIso;

  bool get hasCoordinates => lat != null && lng != null;

  String? get staticMapUrl {
    if (!hasCoordinates) return null;
    return buildCheckInStaticMapUrl(lat: lat!, lng: lng!);
  }

  static CheckInEventData fromMetadata(Map<String, dynamic> m) {
    double? d(String a, String b) {
      final x = m[a] ?? m[b];
      if (x is num) return x.toDouble();
      return double.tryParse(x?.toString() ?? '');
    }

    return CheckInEventData(
      lat: d('lat', 'latitude'),
      lng: d('lng', 'longitude'),
      accuracyMeters: d('accuracy', 'locationAccuracy'),
      address: _nonEmpty(m['address']) ?? _nonEmpty(m['recordedAddress']),
      linkedExchangeId:
          _nonEmpty(m['linkedExchangeId']) ?? _nonEmpty(m['exchangeId']),
      photoUrl: _nonEmpty(m['photoUrl']) ?? _nonEmpty(m['photoEvidenceUrl']),
      clientTimestampIso: m['clientTimestamp']?.toString(),
    );
  }

  static CheckInEventData fromTimelineEvent(TimelineEventModel e) =>
      fromMetadata(e.metadata);

  CheckInEventData mergeEnrichment(Map<String, dynamic>? enrichment) {
    final url = _nonEmpty(enrichment?['photoUrl']);
    if (url == null) return this;
    return CheckInEventData(
      lat: lat,
      lng: lng,
      accuracyMeters: accuracyMeters,
      address: address,
      linkedExchangeId: linkedExchangeId,
      photoUrl: url,
      clientTimestampIso: clientTimestampIso,
    );
  }

  static String? _nonEmpty(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }
}
