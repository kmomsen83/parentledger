import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/child_model.dart';

class ChildService {
static final _db = FirebaseFirestore.instance;
static final _storage = FirebaseStorage.instance;

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
return ChildModel.fromMap(
doc.id,
doc.data(),
caseId: caseId,
);
}).toList();
});
}

/// 🔥 CREATE CHILD (MAIN)
static Future<String> createChild({
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
"photoUrl": null,
"createdAt": FieldValue.serverTimestamp(),
"updatedAt": FieldValue.serverTimestamp(),
});

return ref.id; // 🔥 IMPORTANT for image upload
}

/// 🔥 SIMPLE ADD (LEGACY SUPPORT)
static Future<void> addChild({
required String caseId,
required String name,
int? age,
}) async {
await createChild(
caseId: caseId,
name: name,
dob: DateTime.now().subtract(
Duration(days: (age ?? 5) * 365),
),
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

/// 🔥 PARTIAL UPDATE (SAFE + FLEXIBLE)
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

/// 🔥 UPLOAD CHILD PHOTO (NEW 🔥)
static Future<String> uploadChildPhoto({
required String caseId,
required String childId,
required File file,
}) async {
final ref = _storage
.ref()
.child("cases/$caseId/children/$childId/profile.jpg");

await ref.putFile(file);

final url = await ref.getDownloadURL();

/// 🔥 SAVE URL TO FIRESTORE
await updateChildPartial(
caseId: caseId,
childId: childId,
data: {
"photoUrl": url,
},
);

return url;
}

/// 🔥 DELETE CHILD (WITH IMAGE CLEANUP)
static Future<void> deleteChild({
required String caseId,
required String childId,
}) async {
try {
/// 🔥 DELETE IMAGE IF EXISTS
final ref = _storage
.ref()
.child("cases/$caseId/children/$childId/profile.jpg");

await ref.delete();
} catch (_) {
// ignore if no image exists
}

await _db
.collection("cases")
.doc(caseId)
.collection("children")
.doc(childId)
.delete();
}
}
