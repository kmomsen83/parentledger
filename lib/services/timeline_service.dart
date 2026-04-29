import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/timeline_event_model.dart';
import '../timeline/timeline_mapper.dart';

class TimelineService {

/// ⭐ WATCH CHILD TIMELINE (MASTER STREAM)
static Stream<List<TimelineEventModel>> watchEvents({
required String caseId,
required String childId,
}) {
return FirebaseFirestore.instance
.collection("cases")
.doc(caseId)
.collection("children")
.doc(childId)
.collection("timeline")
.orderBy("date", descending: true)
.snapshots()
.map(
(snap) => snap.docs
.map(TimelineMapper.mapFromFirestore)
.toList(),
);
}

/// ⭐ ADD EVENT
static Future<void> addEvent({
required String caseId,
required String childId,
required String type,
required String title,
String? notes,
required DateTime date,
}) async {

await FirebaseFirestore.instance
.collection("cases")
.doc(caseId)
.collection("children")
.doc(childId)
.collection("timeline")
.add({
"type": type,
"title": title,
"notes": notes ?? "",
"date": Timestamp.fromDate(date),
"createdAt": FieldValue.serverTimestamp(),
});
}

}
