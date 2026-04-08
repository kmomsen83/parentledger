class ExchangeTimelineEvent {

final String id;
final String type;
final DateTime timestamp;
final String createdBy;
final String? notes;
final double? lat;
final double? lng;
final String? proofUrl;
final String? severity;

ExchangeTimelineEvent({
required this.id,
required this.type,
required this.timestamp,
required this.createdBy,
this.notes,
this.lat,
this.lng,
this.proofUrl,
this.severity,
});

factory ExchangeTimelineEvent.fromDoc(doc) {
final d = doc.data();

return ExchangeTimelineEvent(
id: doc.id,
type: d["type"],
timestamp: d["timestamp"].toDate(),
createdBy: d["createdBy"],
notes: d["notes"],
lat: d["lat"],
lng: d["lng"],
proofUrl: d["proofUrl"],
severity: d["severity"],
);
}
}
