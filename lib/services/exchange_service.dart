import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/exchange_model.dart';

class ExchangeService {

static final _db = FirebaseFirestore.instance;

/// ⭐ CREATE EXCHANGE
static Future<void> createExchange({
required String caseId,
required String childId,
required DateTime scheduledTime,
required String type,
required String locationName,
required double lat,
required double lng,
}) async {

final uid = FirebaseAuth.instance.currentUser!.uid;

await _db.collection("exchanges").add({
"caseId": caseId,
"childId": childId,
"scheduledTime": Timestamp.fromDate(scheduledTime),
"type": type,
"locationName": locationName,
"lat": lat,
"lng": lng,
"status": "scheduled",
"createdBy": uid,
"createdAt": Timestamp.now(),
});
}

/// ⭐ DELETE EXCHANGE (FIXES YOUR RED SCREEN)
static Future<void> deleteExchange({
required String caseId,
required String exchangeId,
}) async {

await _db
.collection("exchanges")
.doc(exchangeId)
.delete();
}

/// ⭐ UPDATE EXCHANGE (VERY IMPORTANT FOR FUTURE SCREENS)
static Future<void> updateExchange({
required String exchangeId,
DateTime? scheduledTime,
String? type,
String? locationName,
double? lat,
double? lng,
}) async {

final data = <String, dynamic>{};

if (scheduledTime != null) {
data["scheduledTime"] = Timestamp.fromDate(scheduledTime);
}

if (type != null) data["type"] = type;
if (locationName != null) data["locationName"] = locationName;
if (lat != null) data["lat"] = lat;
if (lng != null) data["lng"] = lng;

if (data.isEmpty) return;

await _db.collection("exchanges").doc(exchangeId).update(data);
}

/// ⭐ WATCH UPCOMING EXCHANGES
static Stream<List<ExchangeModel>> watchUpcoming(String caseId) {

return _db
.collection("exchanges")
.where("caseId", isEqualTo: caseId)
.where(
"scheduledTime",
isGreaterThan: Timestamp.fromDate(DateTime.now()),
)
.orderBy("scheduledTime")
.snapshots()
.map(
(snap) =>
snap.docs.map((d) => ExchangeModel.fromDoc(d)).toList(),
);
}

/// ⭐ WATCH NEXT EXCHANGE (Dashboard)
static Stream<ExchangeModel?> watchNextExchange(String caseId) {

return watchUpcoming(caseId).map((list) {
if (list.isEmpty) return null;
return list.first;
});
}

/// ⭐ CHECK IN
static Future<void> checkIn({
required String exchangeId,
required double actualLat,
required double actualLng,
}) async {

await _db.collection("exchanges").doc(exchangeId).update({
"status": "completed",
"arrivalLat": actualLat,
"arrivalLng": actualLng,
"checkedInAt": Timestamp.now(),
});
}

}
