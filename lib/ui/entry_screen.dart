import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_router.dart';
import 'accept_invite_screen.dart';
import 'login_screen.dart';

class EntryScreen extends StatefulWidget {
final String? inviteId;

const EntryScreen({super.key, this.inviteId});

@override
State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
bool checking = true;
bool _ctaPressed = false;

@override
void initState() {
super.initState();
_handleEntry();
}

/// =====================================
/// 🔥 MAIN ENTRY FLOW (PRODUCTION SAFE)
/// =====================================
Future<void> _handleEntry() async {
final user = FirebaseAuth.instance.currentUser;

await Future.delayed(const Duration(milliseconds: 250));

if (!mounted) return;

/// 🔒 NOT LOGGED IN → SHOW UI
if (user == null) {
setState(() => checking = false);
return;
}

/// 🔗 INVITE FLOW
if (widget.inviteId != null) {
Navigator.pushReplacement(
context,
MaterialPageRoute(
builder: (_) =>
AcceptInviteScreen(inviteId: widget.inviteId!),
),
);
return;
}

  /// Signed in without a pending invite: route into app shell.
  if (!mounted) return;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const AppRouter(),
    ),
  );
  return;
}

/// =====================================
/// 🔥 LOGIN NAVIGATION
/// =====================================
Future<void> _startLogin() async {
await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const LoginScreen(),
  ),
);
if (!mounted) return;
await _handleEntry();
}

/// =====================================
/// UI
/// =====================================
@override
Widget build(BuildContext context) {
return Scaffold(
body: Stack(
children: [

/// 🔥 PREMIUM BACKGROUND IMAGE
Positioned.fill(
child: Image.asset(
"lib/design/premium_entry_screen_background.png",
fit: BoxFit.cover,
),
),

/// 🔥 DARK OVERLAY (CRITICAL FOR TEXT READABILITY)
Positioned.fill(
child: Container(
color: Colors.black.withOpacity(0.55),
),
),

SafeArea(
child: Center(
child: checking
? const CircularProgressIndicator(color: Colors.white)
: Padding(
padding: const EdgeInsets.symmetric(horizontal: 28),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [

/// 🔥 APP NAME
const Text(
"ParentLedger",
style: TextStyle(
fontSize: 36,
fontWeight: FontWeight.w900,
color: Colors.white,
),
),

const SizedBox(height: 10),

/// 🔥 TAGLINE
const Text(
"Custody. Clarity. Peace.",
style: TextStyle(
color: Colors.white70,
fontSize: 14,
),
),

const SizedBox(height: 50),

Listener(
onPointerDown: (_) => setState(() => _ctaPressed = true),
onPointerUp: (_) => setState(() => _ctaPressed = false),
onPointerCancel: (_) => setState(() => _ctaPressed = false),
child: AnimatedScale(
scale: _ctaPressed ? 0.98 : 1.0,
duration: const Duration(milliseconds: 100),
curve: Curves.easeOut,
child: Material(
color: Colors.transparent,
child: InkWell(
onTap: _startLogin,
borderRadius: BorderRadius.circular(30),
splashColor: Colors.white.withValues(alpha: 0.2),
highlightColor: Colors.white.withValues(alpha: 0.1),
child: Ink(
height: 56,
width: double.infinity,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(30),
gradient: const LinearGradient(
colors: [
Color(0xff76c3ff),
Color(0xff3d7cff),
],
),
boxShadow: [
BoxShadow(
color: Color(0xff3d7cff).withValues(alpha: 0.3),
blurRadius: 16,
offset: Offset(0, 8),
),
],
),
child: const Center(
child: Text(
"Continue with Phone",
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800,
color: Colors.white,
letterSpacing: 0.3,
),
),
),
),
),
),
),
),

const SizedBox(height: 20),

/// 🔗 INVITE STATE
if (widget.inviteId != null)
const Text(
"Joining a shared workspace...",
style: TextStyle(
color: Colors.white54,
fontSize: 12,
),
),
],
),
),
),
),
],
),
);
}
}
