import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AcceptInviteScreen extends StatefulWidget {
final String inviteId;

const AcceptInviteScreen({super.key, required this.inviteId});

@override
State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
bool loading = true;
bool joining = false;

Map<String, dynamic>? inviteData;
String? error;

@override
void initState() {
super.initState();
loadInvite();
}

Future<void> loadInvite() async {
try {
final doc = await FirebaseFirestore.instance
.collection("caseInvites")
.doc(widget.inviteId)
.get();

if (!doc.exists) {
setState(() {
error = "Invite not found or expired";
loading = false;
});
return;
}

setState(() {
inviteData = doc.data();
loading = false;
});

} catch (e) {
setState(() {
error = "Failed to load invite";
loading = false;
});
}
}

Future<void> acceptInvite() async {
final user = FirebaseAuth.instance.currentUser;

if (user == null) {
// 🔥 redirect to login WITH inviteId saved
Navigator.pushNamed(context, "/entry",
arguments: {"inviteId": widget.inviteId});
return;
}

setState(() => joining = true);

final db = FirebaseFirestore.instance;

try {
final inviteRef =
db.collection("caseInvites").doc(widget.inviteId);
final inviteSnap = await inviteRef.get();
final invite = inviteSnap.data()!;

final fromUserId = invite["fromUserId"];

final fromUserDoc =
await db.collection("users").doc(fromUserId).get();

final newCaseId = fromUserDoc.data()!["caseId"];

final currentUserRef =
db.collection("users").doc(user.uid);

final currentUserDoc = await currentUserRef.get();
final currentData = currentUserDoc.data();

final existingCaseId = currentData?["caseId"];

/// 🔥 OPTION B — MERGE CASES
if (existingCaseId != null && existingCaseId != newCaseId) {

final oldCaseRef = db.collection("cases").doc(existingCaseId);
final newCaseRef = db.collection("cases").doc(newCaseId);

/// 🔥 MOVE CHILDREN
final children = await oldCaseRef.collection("children").get();
for (var child in children.docs) {
await newCaseRef.collection("children").add(child.data());
}

/// 🔥 MOVE EXPENSES
final expenses = await oldCaseRef.collection("expenses").get();
for (var exp in expenses.docs) {
await newCaseRef.collection("expenses").add(exp.data());
}

/// 🔥 DELETE OLD CASE (optional later)
}

/// 🔥 ADD USER TO NEW CASE
await db.collection("cases").doc(newCaseId).update({
"memberIds": FieldValue.arrayUnion([user.uid]),
});

/// 🔥 MEMBER SUBDOC
await db
.collection("cases")
.doc(newCaseId)
.collection("members")
.doc(user.uid)
.set({
"role": "coparent",
"createdAt": FieldValue.serverTimestamp(),
});

/// 🔥 UPDATE USER
await currentUserRef.update({
"caseId": newCaseId,
"onboardingStep": "connected",
});

/// 🔥 MARK INVITE ACCEPTED
await inviteRef.update({
"status": "accepted",
});

if (!mounted) return;

Navigator.pushNamedAndRemoveUntil(
context, "/home", (_) => false);

} catch (e) {
print("❌ INVITE ERROR: $e");

if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Failed to join workspace")),
);
}
}

if (mounted) setState(() => joining = false);
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: Center(
child: loading
? const CircularProgressIndicator()
: error != null
? Text(error!)
: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [

const Text(
"Join Workspace",
style: TextStyle(fontSize: 26),
),

const SizedBox(height: 20),

ElevatedButton(
onPressed: joining ? null : acceptInvite,
child: Text(
joining ? "Joining..." : "Accept Invite"),
),
],
),
),
);
}
}
