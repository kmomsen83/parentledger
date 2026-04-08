import 'package:cloud_firestore/cloud_firestore.dart';

class RecurringPatternService {

static final _db = FirebaseFirestore.instance;

static Future<void> createPattern({
required String caseId,
required String childId,
required int weekday,
required String time,
required String type,
}) async {

await _db
.collection("cases")
.doc(caseId)
.collection("recurring_patterns")
.add({
"childId": childId,
"weekday": weekday,
"time": time,
"type": type,
"createdAt": Timestamp.now(),
});

}

static Stream<QuerySnapshot> watchPatterns(String caseId) {
return _db
.collection("cases")
.doc(caseId)
.collection("recurring_patterns")
.snapshots();
}

}
