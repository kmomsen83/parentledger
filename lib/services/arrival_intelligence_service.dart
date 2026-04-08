import 'package:geolocator/geolocator.dart';

class ArrivalForecast {

final DateTime eta;
final int delayMinutes;
final double confidence;
final String risk;

ArrivalForecast({
required this.eta,
required this.delayMinutes,
required this.confidence,
required this.risk,
});
}

class ArrivalIntelligenceService {

/// ⭐ MAIN ENGINE
static Future<ArrivalForecast> forecast({

required Position userPosition,
required double exchangeLat,
required double exchangeLng,
required DateTime scheduledTime,

}) async {

final distanceMeters =
Geolocator.distanceBetween(
userPosition.latitude,
userPosition.longitude,
exchangeLat,
exchangeLng,
);

/// ⭐ assume driving speed (replace later with Maps API)
const avgSpeedMetersPerSecond = 12.5;

final travelSeconds =
distanceMeters / avgSpeedMetersPerSecond;

final eta =
DateTime.now().add(Duration(
seconds: travelSeconds.round(),
));

final delay =
eta.difference(scheduledTime).inMinutes;

/// ⭐ Confidence Engine
double confidence;

if (distanceMeters < 500) {
confidence = 0.95;
} else if (distanceMeters < 2000) {
confidence = 0.85;
} else if (distanceMeters < 5000) {
confidence = 0.72;
} else {
confidence = 0.55;
}

/// ⭐ Risk Classification
String risk;

if (delay > 10) {
risk = "High";
} else if (delay > 3) {
risk = "Moderate";
} else {
risk = "Low";
}

return ArrivalForecast(
eta: eta,
delayMinutes: delay,
confidence: confidence,
risk: risk,
);
}
}
