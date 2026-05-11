import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CodeVerificationScreen extends StatefulWidget {
final String verificationId;
final String phone;

const CodeVerificationScreen({
super.key,
required this.verificationId,
required this.phone,
});

@override
State<CodeVerificationScreen> createState() =>
_CodeVerificationScreenState();
}

class _CodeVerificationScreenState
extends State<CodeVerificationScreen> {
final TextEditingController codeController = TextEditingController();

bool loading = false;

/// 🔥 FORMAT PHONE NUMBER
String prettyPhone(String phone) {
final digits = phone.replaceAll(RegExp(r'\D'), '');

if (digits.length == 11 && digits.startsWith("1")) {
return "(${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}";
}

return phone;
}

/// 🔥 VERIFY FUNCTION (FULLY STABLE)
Future<void> verify() async {
if (loading) return;

final code = codeController.text.trim();

if (code.length != 6) {
_error("Enter valid 6-digit code");
return;
}

setState(() => loading = true);

try {
final credential = PhoneAuthProvider.credential(
verificationId: widget.verificationId,
smsCode: code,
);

await FirebaseAuth.instance.signInWithCredential(credential);

if (!mounted) return;

/// 🔥 RETURN TO ROOT (APP ROUTER TAKES OVER)
Navigator.of(context).popUntil((route) => route.isFirst);

} catch (e) {

if (!mounted) return;

_error("Invalid or expired code");
setState(() => loading = false);
}
}

void _error(String message) {
ScaffoldMessenger.of(context)
.showSnackBar(SnackBar(content: Text(message)));
}

@override
void dispose() {
codeController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: Stack(
children: [
/// 🔥 BACKGROUND
Positioned.fill(
child: Image.asset(
"lib/design/premium_entry_screen_background.png",
fit: BoxFit.cover,
),
),

Positioned.fill(
child: Container(color: Colors.black.withValues(alpha:.65)),
),

SafeArea(
child: Padding(
padding: const EdgeInsets.all(26),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
/// 🔙 BACK BUTTON
IconButton(
onPressed: () => Navigator.pop(context),
icon: const Icon(Icons.arrow_back),
),

const SizedBox(height: 20),

/// 🔥 TITLE
const Text(
"Verify Code",
style: TextStyle(
fontSize: 32,
fontWeight: FontWeight.w900,
),
),

const SizedBox(height: 10),

/// 📱 PHONE DISPLAY
Text(
"Sent to ${prettyPhone(widget.phone)}",
style: const TextStyle(
color: Colors.white70,
),
),

const SizedBox(height: 40),

/// 🔢 CODE INPUT
Container(
decoration: BoxDecoration(
color: Colors.white.withValues(alpha:.08),
borderRadius: BorderRadius.circular(22),
border: Border.all(
color: Colors.white.withValues(alpha:.15),
),
),
child: TextField(
controller: codeController,
keyboardType: TextInputType.number,
textAlign: TextAlign.center,
maxLength: 6,
style: const TextStyle(
fontSize: 22,
letterSpacing: 6,
),
decoration: const InputDecoration(
hintText: "------",
border: InputBorder.none,
counterText: "",
contentPadding: EdgeInsets.all(20),
),
),
),

const SizedBox(height: 24),

/// 🔥 VERIFY BUTTON
GestureDetector(
onTap: verify,
child: Container(
height: 64,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(30),
gradient: const LinearGradient(
colors: [
Color(0xff76c3ff),
Color(0xff3d7cff),
],
),
),
child: Center(
child: loading
? const CircularProgressIndicator(
color: Colors.white,
)
: const Text(
"Verify & Continue",
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800,
),
),
),
),
),

const SizedBox(height: 16),

/// 🔁 RESEND TEXT
const Center(
child: Text(
"Didn’t get a code? Try again",
style: TextStyle(
color: Colors.white54,
fontSize: 12,
),
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
