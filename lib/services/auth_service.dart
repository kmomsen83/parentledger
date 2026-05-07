import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
static Future<void> ensureUserExists(User user) async {
final ref =
FirebaseFirestore.instance.collection("users").doc(user.uid);

final doc = await ref.get();

/// 🔥 FIRST TIME USER
if (!doc.exists) {
await ref.set({
"uid": user.uid,
"phone": user.phoneNumber,
"createdAt": FieldValue.serverTimestamp(),

"isPremium": false,
"onboardingStep": "account_type",
"coparentConnected": false,
"childrenCount": 0,

"caseId": null,
"role": null,

/// 🔥 ADD THIS HERE TOO
"lastLogin": FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
} else {
/// 🔥 EXISTING USER → UPDATE LAST LOGIN ONLY
await ref.set({
"lastLogin": FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
}
}
}
