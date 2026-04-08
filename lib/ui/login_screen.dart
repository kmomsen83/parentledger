import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
const LoginScreen({super.key});

@override
State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
final phone = TextEditingController();
final code = TextEditingController();

String verificationId = "";
bool codeSent = false;
bool loading = false;

Future<void> sendCode() async {
setState(() => loading = true);

await FirebaseAuth.instance.verifyPhoneNumber(
phoneNumber: phone.text.trim(),

verificationCompleted: (cred) async {
await FirebaseAuth.instance.signInWithCredential(cred);
},

verificationFailed: (e) {
_error(e.message ?? "Failed");
setState(() => loading = false);
},

codeSent: (id, _) {
verificationId = id;
setState(() {
codeSent = true;
loading = false;
});
},

codeAutoRetrievalTimeout: (id) {
verificationId = id;
},
);
}

Future<void> verifyCode() async {
try {
final cred = PhoneAuthProvider.credential(
verificationId: verificationId,
smsCode: code.text.trim(),
);

await FirebaseAuth.instance.signInWithCredential(cred);

if (!mounted) return;

} catch (e) {
_error("Invalid code");
}
}

void _error(String msg) {
ScaffoldMessenger.of(context)
.showSnackBar(SnackBar(content: Text(msg)));
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: Padding(
padding: const EdgeInsets.all(28),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
if (!codeSent)
TextField(
controller: phone,
keyboardType: TextInputType.phone,
decoration:
const InputDecoration(labelText: "Phone"),
),

if (codeSent)
TextField(
controller: code,
keyboardType: TextInputType.number,
decoration:
const InputDecoration(labelText: "Code"),
),

const SizedBox(height: 20),

ElevatedButton(
onPressed: loading
? null
: codeSent
? verifyCode
: sendCode,
child: Text(codeSent ? "Verify" : "Send Code"),
),
],
),
),
);
}
}
