import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InviteService {
static final _db = FirebaseFirestore.instance;

/// ================================
/// 🔥 ACCEPT INVITE (FULL FLOW)
/// ================================
static Future<void> acceptInvite(String inviteId) async {
final user = FirebaseAuth.instance.currentUser;

if (user == null) {
throw Exception("User not authenticated");
}

final inviteRef = _db.collection("caseInvites").doc(inviteId);
final userRef = _db.collection("users").doc(user.uid);

await _db.runTransaction((tx) async {
final inviteSnap = await tx.get(inviteRef);

if (!inviteSnap.exists) {
throw Exception("Invite not found");
}

final invite = inviteSnap.data() as Map<String, dynamic>;

if (invite["status"] != "pending") {
throw Exception("Invite already used");
}

final caseId = invite["caseId"];

if (caseId == null) {
throw Exception("Invalid invite");
}

/// 🔥 GET USER DATA
final userSnap = await tx.get(userRef);
final userData = userSnap.data();

final existingCaseId = userData?["caseId"];

/// =========================================
/// 🔥 MERGE FLAG (OPTION B SAFE)
/// =========================================
if (existingCaseId != null && existingCaseId != caseId) {
tx.update(userRef, {
"mergeFromCaseId": existingCaseId,
});
}

/// 🔥 JOIN NEW CASE
tx.set(userRef, {
"caseId": caseId,
"onboardingStep": "children_added",
}, SetOptions(merge: true));

/// 🔥 ADD TO CASE MEMBERS
final memberRef = _db
.collection("cases")
.doc(caseId)
.collection("members")
.doc(user.uid);

tx.set(memberRef, {
"userId": user.uid,
"joinedAt": FieldValue.serverTimestamp(),
});

/// 🔥 MARK INVITE ACCEPTED
tx.update(inviteRef, {
"status": "accepted",
"acceptedBy": user.uid,
"acceptedAt": FieldValue.serverTimestamp(),
});
});

/// =========================================
/// 🔥 HANDLE MERGE OUTSIDE TX (SAFE)
/// =========================================
await _handleMergeIfNeeded(user.uid);
}

/// ================================
/// 🔥 MERGE CASES (SAFE OUTSIDE TX)
/// ================================
static Future<void> _handleMergeIfNeeded(String userId) async {
final userRef = _db.collection("users").doc(userId);
final userSnap = await userRef.get();

final data = userSnap.data();
final mergeFrom = data?["mergeFromCaseId"];
final newCaseId = data?["caseId"];

if (mergeFrom == null || newCaseId == null) return;

final oldChildren = await _db
.collection("cases")
.doc(mergeFrom)
.collection("children")
.get();

for (final doc in oldChildren.docs) {
await _db
.collection("cases")
.doc(newCaseId)
.collection("children")
.add(doc.data());
}

/// 🔥 CLEAN UP FLAG
await userRef.update({
"mergeFromCaseId": FieldValue.delete(),
});
}

/// ================================
/// 🔥 AUTO ACCEPT (ROUTER)
/// ================================
static Future<void> checkAndAcceptInvite(User user) async {
final invites = await _db
.collection("caseInvites")
.where("toPhone", isEqualTo: user.phoneNumber)
.where("status", isEqualTo: "pending")
.get();

if (invites.docs.isEmpty) return;

final invite = invites.docs.first;

await acceptInvite(invite.id);
}
}
