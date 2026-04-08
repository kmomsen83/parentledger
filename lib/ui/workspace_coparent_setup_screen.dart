import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/design.dart';

class WorkspaceCoparentSetupScreen extends StatefulWidget {
const WorkspaceCoparentSetupScreen({super.key});

@override
State<WorkspaceCoparentSetupScreen> createState() =>
_WorkspaceCoparentSetupScreenState();
}

class _WorkspaceCoparentSetupScreenState
extends State<WorkspaceCoparentSetupScreen> {
final phone = TextEditingController();
bool loading = false;

/// ================================
/// 🔥 NORMALIZE PHONE (STRICT)
/// ================================
String normalize(String input) {
String digits = input.replaceAll(RegExp(r'\D'), '');

if (digits.startsWith('1')) {
digits = digits.substring(1);
}

if (digits.length == 10) return "+1$digits";

return "+$digits";
}

bool isValidPhone(String phone) {
return RegExp(r'^\+1\d{10}$').hasMatch(phone);
}

void _error(String msg) {
ScaffoldMessenger.of(context)
.showSnackBar(SnackBar(content: Text(msg)));
}

/// ================================
/// 🔥 SEND INVITE (PRODUCTION SAFE)
/// ================================
Future<void> sendInvite() async {
if (loading) return;

final user = FirebaseAuth.instance.currentUser;

if (user == null) {
_error("User not authenticated");
return;
}

final db = FirebaseFirestore.instance;
final normalized = normalize(phone.text.trim());

if (!isValidPhone(normalized)) {
_error("Enter valid US phone number");
return;
}

setState(() => loading = true);

try {
/// 🔥 GET USER (CASE ID REQUIRED)
final userDoc =
await db.collection("users").doc(user.uid).get();

final data = userDoc.data();

if (data == null || data["caseId"] == null) {
throw Exception("Missing caseId");
}

final caseId = data["caseId"];

/// 🔥 PREVENT DUPLICATE INVITES
final existing = await db
.collection("caseInvites")
.where("toPhone", isEqualTo: normalized)
.where("caseId", isEqualTo: caseId)
.where("status", isEqualTo: "pending")
.limit(1)
.get();

if (existing.docs.isNotEmpty) {
_error("Invite already sent");
setState(() => loading = false);
return;
}

/// 🔥 CREATE INVITE
final inviteRef = await db.collection("caseInvites").add({
"fromUserId": user.uid,
"toPhone": normalized,
"status": "pending",
"caseId": caseId,
"createdAt": FieldValue.serverTimestamp(),
});

/// 🔥 BUILD SMS LINK
final link =
"https://parentledger.app/invite?id=${inviteRef.id}";

final smsUri = Uri(
scheme: 'sms',
path: normalized,
queryParameters: {
'body': "Join me on ParentLedger: $link",
},
);

/// 🔥 LAUNCH SMS SAFELY
if (!await canLaunchUrl(smsUri)) {
throw Exception("Cannot open SMS app");
}

await launchUrl(smsUri);

/// 🔥 MOVE USER FORWARD
await db.collection("users").doc(user.uid).update({
"onboardingStep": "coparent_invited",
});

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Invite sent")),
);

} catch (e) {
print("❌ INVITE ERROR: $e");
_error("Failed to send invite");
}

if (mounted) {
setState(() => loading = false);
}
}

/// ================================
/// 🔥 SKIP (SAFE)
/// ================================
Future<void> skip() async {
if (loading) return;

final user = FirebaseAuth.instance.currentUser;

if (user == null) return;

setState(() => loading = true);

try {
await FirebaseFirestore.instance
.collection("users")
.doc(user.uid)
.update({
"onboardingStep": "coparent_invited",
});
} catch (e) {
print("❌ SKIP ERROR: $e");
_error("Failed to continue");
}

if (mounted) {
setState(() => loading = false);
}
}

@override
void dispose() {
phone.dispose();
super.dispose();
}

/// ================================
/// UI
/// ================================
@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.transparent,
body: Stack(
fit: StackFit.expand,
children: [

/// 🔥 BACKGROUND
Container(decoration: PLDesign.screenGradient),

SafeArea(
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 28),
child: Column(
children: [

const SizedBox(height: 80),

const Text(
"Connect Co-Parent",
style: PLDesign.pageTitle,
),

const SizedBox(height: 10),

const Text(
"Invite your co-parent via SMS to connect your shared parenting workspace.",
style: PLDesign.body,
textAlign: TextAlign.center,
),

const SizedBox(height: 50),

/// 🔥 PHONE INPUT
Container(
padding: const EdgeInsets.symmetric(horizontal: 18),
height: 58,
decoration: BoxDecoration(
color: PLDesign.surface,
borderRadius: BorderRadius.circular(18),
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: Center(
child: TextField(
controller: phone,
style: const TextStyle(color: Colors.white),
keyboardType: TextInputType.phone,
decoration: const InputDecoration(
hintText: "+1 555 123 4567",
hintStyle: TextStyle(color: Colors.white54),
border: InputBorder.none,
),
),
),
),

const SizedBox(height: 26),

/// 🔥 SEND INVITE BUTTON
GestureDetector(
onTap: loading ? null : sendInvite,
child: Container(
height: 58,
decoration: BoxDecoration(
gradient: PLDesign.primaryGradient,
borderRadius: BorderRadius.circular(18),
boxShadow: [
BoxShadow(
color: PLDesign.primary.withOpacity(.45),
blurRadius: 30,
)
],
),
child: Center(
child: loading
? const CircularProgressIndicator(
color: Colors.white,
)
: const Text(
"Send Invite",
style: PLDesign.buttonText,
),
),
),
),

const SizedBox(height: 18),

/// 🔥 SKIP
TextButton(
onPressed: loading ? null : skip,
child: const Text(
"Skip for now",
style: TextStyle(color: Colors.white70),
),
),
],
),
),
),
],
),
);
}
}
