import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/design/design.dart';

class SignupScreen extends StatefulWidget {
const SignupScreen({super.key});

@override
State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
final firstName = TextEditingController();
final lastName = TextEditingController();
final emailController = TextEditingController();

String? role;
bool loading = false;

/// ================================
/// COMPLETE SIGNUP
/// ================================
Future<void> _completeSignup() async {
if (loading) return;

final user = FirebaseAuth.instance.currentUser;

if (user == null) {
_error("User not authenticated");
return;
}

if (firstName.text.trim().isEmpty ||
lastName.text.trim().isEmpty ||
role == null) {
_error("Complete all fields");
return;
}

setState(() => loading = true);

final db = FirebaseFirestore.instance;

final userRef = db.collection("users").doc(user.uid);
final caseRef = db.collection("cases").doc();

try {
await userRef.set({
"firstName": firstName.text.trim(),
"lastName": lastName.text.trim(),
"email": emailController.text.trim(),
"phone": user.phoneNumber,
"role": role,
"caseId": caseRef.id,
"onboardingStep": "profile_complete",
"isPremium": false,
"createdAt": FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

await caseRef.set({
"ownerId": user.uid,
"memberIds": [user.uid],
"createdAt": FieldValue.serverTimestamp(),
});

await caseRef.collection("members").doc(user.uid).set({
"role": role,
"createdAt": FieldValue.serverTimestamp(),
});

} catch (e) {
_error("Signup failed");
}

if (!mounted) return;
setState(() => loading = false);
}

void _error(String msg) {
ScaffoldMessenger.of(context)
.showSnackBar(SnackBar(content: Text(msg)));
}

@override
void dispose() {
firstName.dispose();
lastName.dispose();
emailController.dispose();
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

/// 🔥 BACKGROUND
Container(decoration: PLDesign.screenGradient),

SafeArea(
child: SingleChildScrollView(
padding: EdgeInsets.fromLTRB(
24,
24,
24,
MediaQuery.of(context).viewInsets.bottom + 24,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

const SizedBox(height: 20),

/// TITLE
const Text(
"Create Account",
style: TextStyle(
fontSize: 34,
fontWeight: FontWeight.w900,
color: Colors.white,
),
),

const SizedBox(height: 30),

_inputField("First Name", firstName, capitalize: true),
const SizedBox(height: 14),

_inputField("Last Name", lastName, capitalize: true),
const SizedBox(height: 14),

_inputField(
"Email (optional)",
emailController,
type: TextInputType.emailAddress,
),

const SizedBox(height: 20),

/// 🔥 ROLE (FIXED STYLE — NO DOUBLE BUBBLE)
_dropdownField(),

const SizedBox(height: 40),

/// CTA
PLDesign.primaryButton(
label: loading ? "Creating..." : "Continue",
onTap: loading ? () {} : _completeSignup,
),
],
),
),
),
],
),
);
}

/// 🔥 CLEAN INPUT (MATCHES ENTRY SCREEN)
Widget _inputField(
String label,
TextEditingController controller, {
TextInputType type = TextInputType.text,
bool capitalize = false,
}) {
return Container(
decoration: BoxDecoration(
color: Colors.white.withOpacity(.08),
borderRadius: BorderRadius.circular(22),
border: Border.all(
color: Colors.white.withOpacity(.15),
),
),
child: TextField(
controller: controller,
keyboardType: type,
textCapitalization:
capitalize ? TextCapitalization.words : TextCapitalization.none,
style: const TextStyle(color: Colors.white),
decoration: InputDecoration(
hintText: label,
hintStyle: const TextStyle(color: Colors.white54),
border: InputBorder.none,
contentPadding: const EdgeInsets.all(20),
),
),
);
}

/// 🔥 FIXED DROPDOWN (NO DOUBLE CONTAINER)
Widget _dropdownField() {
return Container(
decoration: BoxDecoration(
color: Colors.white.withOpacity(.08),
borderRadius: BorderRadius.circular(22),
border: Border.all(
color: Colors.white.withOpacity(.15),
),
),
padding: const EdgeInsets.symmetric(horizontal: 16),
child: DropdownButtonFormField<String>(
initialValue: role,
dropdownColor: const Color(0xff1c1f2e),
hint: const Text(
"Select Role",
style: TextStyle(color: Colors.white70),
),
items: const [
DropdownMenuItem(value: "Mom", child: Text("Mom")),
DropdownMenuItem(value: "Dad", child: Text("Dad")),
DropdownMenuItem(value: "Guardian", child: Text("Guardian")),
],
onChanged: (v) => setState(() => role = v),
style: const TextStyle(color: Colors.white),
decoration: const InputDecoration(
border: InputBorder.none,
),
iconEnabledColor: Colors.white70,
),
);
}
}
