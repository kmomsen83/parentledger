import 'package:firebase_auth/firebase_auth.dart';
import 'exchange_timeline_service.dart';

class ExchangeTimelineWriter {

static String get uid =>
FirebaseAuth.instance.currentUser!.uid;

/// ⭐ Navigation started
static Future<void> navigationStarted({
required String caseId,
required String exchangeId,
}) async {

await ExchangeTimelineService.addEvent(
caseId: caseId,
exchangeId: exchangeId,
type: "navigation_started",
createdBy: uid,
severity: "info",
);
}

/// ⭐ Arrived at location
static Future<void> arrived({
required String caseId,
required String exchangeId,
required double lat,
required double lng,
}) async {

await ExchangeTimelineService.addEvent(
caseId: caseId,
exchangeId: exchangeId,
type: "arrival_verified",
createdBy: uid,
lat: lat,
lng: lng,
severity: "proof",
);
}

/// ⭐ Check-in completed
static Future<void> checkIn({
required String caseId,
required String exchangeId,
}) async {

await ExchangeTimelineService.addEvent(
caseId: caseId,
exchangeId: exchangeId,
type: "check_in_completed",
createdBy: uid,
severity: "legal",
);
}

/// ⭐ Late flag
static Future<void> late({
required String caseId,
required String exchangeId,
required int minutes,
}) async {

await ExchangeTimelineService.addEvent(
caseId: caseId,
exchangeId: exchangeId,
type: "late_flag",
createdBy: uid,
notes: "Late by $minutes minutes",
severity: "risk",
);
}

/// ⭐ Exchange completed
static Future<void> completed({
required String caseId,
required String exchangeId,
}) async {

await ExchangeTimelineService.addEvent(
caseId: caseId,
exchangeId: exchangeId,
type: "exchange_completed",
createdBy: uid,
severity: "legal",
);
}

}
