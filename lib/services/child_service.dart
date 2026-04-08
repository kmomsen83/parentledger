import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/child_model.dart';

class ChildService {
static final _db = FirebaseFirestore.instance;

/// 🔥 WATCH CHILDREN (REALTIME)
static Stream<List<ChildModel>> watchChildren(String caseId) {
return _db
.collection("cases")
.doc(caseId)
.collection("children")
.orderBy("createdAt")
.snapshots()
.map((snap) {
return snap.docs.map((doc) {
return ChildModel.fromMap(doc.id, doc.data());
}).toList();
});
}

/// 🔥 CREATE CHILD (MAIN)
static Future<void> createChild({
required String caseId,
required String name,
required DateTime dob,
required String gender,
String? medicalNotes,
}) async {
final ref = _db
.collection("cases")
.doc(caseId)
.collection("children")
.doc();

await ref.set({
"name": name,
"dob": Timestamp.fromDate(dob),
"gender": gender,
"medicalNotes": medicalNotes ?? "",
"createdAt": FieldValue.serverTimestamp(),
});
}

/// 🔥 SIMPLE ADD (FOR YOUR CURRENT UI)
static Future<void> addChild({
required String caseId,
required String name,
int? age,
}) async {
await createChild(
caseId: caseId,
name: name,
dob: DateTime.now().subtract(Duration(days: (age ?? 5) * 365)),
gender: "unknown",
);
}

/// 🔥 UPDATE CHILD (FULL)
static Future<void> updateChild({
required String caseId,
required String childId,
required String name,
required DateTime dob,
required String gender,
String? medicalNotes,
}) async {
await _db
.collection("cases")
.doc(caseId)
.collection("children")
.doc(childId)
.update({
"name": name,
"dob": Timestamp.fromDate(dob),
"gender": gender,
"medicalNotes": medicalNotes ?? "",
"updatedAt": FieldValue.serverTimestamp(),
});
}

/// 🔥 PARTIAL UPDATE (THIS FIXES YOUR ERROR)
static Future<void> updateChildPartial({
required String caseId,
required String childId,
required Map<String, dynamic> data,
}) async {
await _db
.collection("cases")
.doc(caseId)
.collection("children")
.doc(childId)
.update({
...data,
"updatedAt": FieldValue.serverTimestamp(),
});
}

/// 🔥 DELETE
static Future<void> deleteChild({
required String caseId,
required String childId,
}) async {
await _db
.collection("cases")
.doc(caseId)
.collection("children")
.doc(childId)
.delete();
}
}


