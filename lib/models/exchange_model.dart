import 'package:cloud_firestore/cloud_firestore.dart';

class ExchangeModel {
final String id;
final String caseId;
final String childId;

final DateTime scheduledTime;
final String type;

final String locationName;
final double lat;
final double lng;

final String status;

final String createdBy;
final DateTime createdAt;

final double? arrivalLat;
final double? arrivalLng;
final DateTime? checkedInAt;

ExchangeModel({
required this.id,
required this.caseId,
required this.childId,
required this.scheduledTime,
required this.type,
required this.locationName,
required this.lat,
required this.lng,
required this.status,
required this.createdBy,
required this.createdAt,
this.arrivalLat,
this.arrivalLng,
this.checkedInAt,
});

factory ExchangeModel.fromDoc(DocumentSnapshot doc) {
final d = doc.data() as Map<String, dynamic>;

return ExchangeModel(
id: doc.id,
caseId: d["caseId"],
childId: d["childId"],
scheduledTime: (d["scheduledTime"] as Timestamp).toDate(),
type: d["type"],
locationName: d["locationName"],
lat: (d["lat"] as num).toDouble(),
lng: (d["lng"] as num).toDouble(),
status: d["status"],
createdBy: d["createdBy"],
createdAt: (d["createdAt"] as Timestamp).toDate(),
arrivalLat: d["arrivalLat"] != null
? (d["arrivalLat"] as num).toDouble()
: null,
arrivalLng: d["arrivalLng"] != null
? (d["arrivalLng"] as num).toDouble()
: null,
checkedInAt: d["checkedInAt"] != null
? (d["checkedInAt"] as Timestamp).toDate()
: null,
);
}
}
