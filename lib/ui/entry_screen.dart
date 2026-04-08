import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'accept_invite_screen.dart';
import '../design/design.dart';

class EntryScreen extends StatefulWidget {
final String? inviteId;

const EntryScreen({super.key, this.inviteId});

@override
State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
bool checking = true;

@override
void initState() {
super.initState();
handleEntry();
}

/// 🔥 MAIN ENTRY LOGIC
Future<void> handleEntry() async {
final user = FirebaseAuth.instance.currentUser;

/// ⏳ small delay for smooth UX
await Future.delayed(const Duration(milliseconds: 300));

if (!mounted) return;

/// ================================
/// 🔥 CASE 1: USER NOT LOGGED IN
/// ================================
if (user == null) {
setState(() => checking = false);
return;
}

/// ================================
/// 🔥 CASE 2: USER LOGGED IN
/// ================================
if (widget.inviteId != null) {
/// 🚀 go accept invite
Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (_) =>
AcceptInviteScreen(inviteId: widget.inviteId!),
),
);
return;
}

/// 🚀 normal app flow
Navigator.pushReplacementNamed(context, "/router");
}

/// 🔥 CALLED AFTER LOGIN / SIGNUP
void onAuthSuccess() {
if (widget.inviteId != null) {
Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (_) =>
AcceptInviteScreen(inviteId: widget.inviteId!),
),
);
} else {
Navigator.pushReplacementNamed(context, "/router");
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: Stack(
children: [

/// 🔥 BACKGROUND
Container(decoration: PLDesign.screenGradient),

SafeArea(
child: Center(
child: checking
? const CircularProgressIndicator()
: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [

/// 🔥 TITLE
const Text(
"ParentLedger",
style: TextStyle(
fontSize: 34,
fontWeight: FontWeight.w900,
color: Colors.white,
),
),

const SizedBox(height: 10),

const Text(
"Custody. Clarity. Peace.",
style: TextStyle(color: Colors.white70),
),

const SizedBox(height: 40),

/// 🔥 LOGIN BUTTON
_button(
"Continue with Phone",
() async {
/// 🔥 YOUR PHONE AUTH FLOW HERE
/// After success:
onAuthSuccess();
},
),

const SizedBox(height: 16),

/// 🔥 DEBUG (optional remove later)
if (widget.inviteId != null)
const Text(
"Joining a workspace...",
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

/// 🔥 BUTTON
Widget _button(String text, VoidCallback onTap) {
return GestureDetector(
onTap: onTap,
child: Container(
width: 260,
height: 56,
decoration: BoxDecoration(
gradient: PLDesign.primaryGradient,
borderRadius: BorderRadius.circular(20),
),
child: Center(
child: Text(text, style: PLDesign.buttonText),
),
),
);
}
}
