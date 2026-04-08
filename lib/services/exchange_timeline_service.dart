import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exchange_timeline_event.dart';

class ExchangeTimelineService {

static final _db = FirebaseFirestore.instance;

static Stream<List<ExchangeTimelineEvent>> watchTimeline({
required String caseId,
required String exchangeId,
}) {

return _db
.collection("cases")
.doc(caseId)
.collection("exchanges")
.doc(exchangeId)
.collection("timeline")
.orderBy("timestamp")
.snapshots()
.map((snap) =>
snap.docs.map((d) =>
ExchangeTimelineEvent.fromDoc(d)).toList());
}

static Future<void> addEvent({
required String caseId,
required String exchangeId,
required String type,
required String createdBy,
String? notes,
double? lat,
double? lng,
String? severity,
}) async {

await _db
.collection("cases")
.doc(caseId)
.collection("exchanges")
.doc(exchangeId)
.collection("timeline")
.add({
"type": type,
"timestamp": Timestamp.now(),
"createdBy": createdBy,
"notes": notes,
"lat": lat,
"lng": lng,
"severity": severity,
});
}

}
