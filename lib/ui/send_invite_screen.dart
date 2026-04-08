import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/design.dart';

class SendInviteScreen extends StatefulWidget {
const SendInviteScreen({super.key});

@override
State<SendInviteScreen> createState() => _SendInviteScreenState();
}

class _SendInviteScreenState extends State<SendInviteScreen> {
final phoneController = TextEditingController();

bool loading = false;

/// 🔥 NORMALIZE PHONE
String normalize(String input) {
String digits = input.replaceAll(RegExp(r'\D'), '');

if (digits.startsWith('1')) {
digits = digits.substring(1);
}

if (digits.length == 10) return "+1$digits";

return "+$digits";
}

void _error(String msg) {
ScaffoldMessenger.of(context)
.showSnackBar(SnackBar(content: Text(msg)));
}

/// ================================
/// 🔥 SEND INVITE (FINAL VERSION)
/// ================================
Future<void> sendInvite() async {
if (loading) return;

final user = FirebaseAuth.instance.currentUser;

if (user == null) {
_error("Not authenticated");
return;
}

final normalized = normalize(phoneController.text);

if (normalized.length < 12) {
_error("Enter valid phone number");
return;
}

setState(() => loading = true);

final db = FirebaseFirestore.instance;

try {
/// 🔥 GET USER CASE
final userDoc =
await db.collection("users").doc(user.uid).get();

final data = userDoc.data();

if (data == null || data["caseId"] == null) {
throw Exception("Missing case");
}

final caseId = data["caseId"];

/// 🔥 CREATE INVITE
final inviteRef = await db.collection("caseInvites").add({
"fromUserId": user.uid,
"toPhone": normalized,
"status": "pending",
"caseId": caseId,
"createdAt": FieldValue.serverTimestamp(),
});

/// 🔥 LINK
final link =
"https://parentledger.app/invite?id=${inviteRef.id}";

final smsUri = Uri.parse(
"sms:$normalized?body=Join me on ParentLedger: $link",
);

await launchUrl(smsUri);

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Invite sent")),
);

phoneController.clear();

} catch (e) {
print("❌ INVITE ERROR: $e");
_error("Failed to send invite");
}

if (mounted) {
setState(() => loading = false);
}
}

@override
void dispose() {
phoneController.dispose();
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
children: [
Container(decoration: PLDesign.screenGradient),

SafeArea(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

const SizedBox(height: 20),

/// TITLE
const Text(
"Invite Co-Parent",
style: PLDesign.pageTitle,
),

const SizedBox(height: 10),

const Text(
"Send an invite to connect and share your parenting workspace.",
style: PLDesign.body,
),

const SizedBox(height: 40),

/// INPUT
Container(
padding: const EdgeInsets.symmetric(horizontal: 16),
height: 56,
decoration: BoxDecoration(
color: PLDesign.surface,
borderRadius: BorderRadius.circular(16),
border: Border.all(color: PLDesign.border),
),
child: Center(
child: TextField(
controller: phoneController,
keyboardType: TextInputType.phone,
style: const TextStyle(color: Colors.white),
decoration: const InputDecoration(
hintText: "+1 555 123 4567",
hintStyle:
TextStyle(color: Colors.white54),
border: InputBorder.none,
),
),
),
),

const SizedBox(height: 24),

/// BUTTON
GestureDetector(
onTap: loading ? null : sendInvite,
child: Container(
height: 56,
decoration: BoxDecoration(
gradient: PLDesign.primaryGradient,
borderRadius: BorderRadius.circular(18),
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

const Spacer(),

/// INFO
const Text(
"You can invite anytime from settings.",
style: TextStyle(color: Colors.white54),
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
