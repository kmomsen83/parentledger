import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionScreen extends StatefulWidget {
const SubscriptionScreen({super.key});

@override
State<SubscriptionScreen> createState() =>
_SubscriptionScreenState();
}

class _SubscriptionScreenState
extends State<SubscriptionScreen> {

/// 🔥 DEFAULT TO YEARLY (HIGHER CONVERSION)
String plan = "yearly";
bool loading = false;

Future<void> startSubscription() async {
if (loading) return;

setState(() => loading = true);

try {
final auth = FirebaseAuth.instance;
User? user = auth.currentUser;

if (user == null) {
final cred = await auth.signInAnonymously();
user = cred.user;
}

final priceId = plan == "monthly"
? "price_1TEvjW2St2PgxIkbdw5dZ5Td"
: "price_1TEvjV2St2PgxIkb9VncCrta";

final response = await http.post(
Uri.parse(
"https://us-central1-parentledger-prod.cloudfunctions.net/createSubscriptionV2",
),
headers: {"Content-Type": "application/json"},
body: jsonEncode({"priceId": priceId}),
);

final data = jsonDecode(response.body);

await Stripe.instance.initPaymentSheet(
paymentSheetParameters: SetupPaymentSheetParameters(
merchantDisplayName: "ParentLedger",
customerId: data["customerId"],
customerEphemeralKeySecret: data["ephemeralKey"],
paymentIntentClientSecret: data["clientSecret"],
style: ThemeMode.dark,
),
);

await Stripe.instance.presentPaymentSheet();

/// 🔥 SAVE STATE
await FirebaseFirestore.instance
.collection('users')
.doc(user!.uid)
.set({
"isPremium": true,
"plan": plan,
"onboardingStep": "subscribed",
"trialStart": FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Payment failed")),
);
}

if (mounted) setState(() => loading = false);
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: Stack(
children: [

/// BACKGROUND
Positioned.fill(
child: Image.asset(
"lib/design/premium_entry_screen_background.png",
fit: BoxFit.cover,
),
),

Positioned.fill(
child: Container(
color: Colors.black.withOpacity(.7),
),
),

SafeArea(
child: SingleChildScrollView(
padding: const EdgeInsets.all(26),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

const SizedBox(height: 10),

/// 🔥 HEADLINE
const Text(
"Clarity. Protection. Peace.",
style: TextStyle(
fontSize: 34,
fontWeight: FontWeight.w900,
),
),

const SizedBox(height: 12),

const Text(
"Document everything. Stay protected. "
"Be ready for anything.",
style: TextStyle(
color: Colors.white70,
),
),

const SizedBox(height: 30),

/// 🔥 VALUE STACK
_feature("Court-admissible documentation"),
_feature("AI-powered custody insights"),
_feature("Secure communication tracking"),
_feature("Expense & payment tracking"),

const SizedBox(height: 30),

/// 🔥 PLANS
_planCard(
title: "Yearly",
price: "\$159.99 / year",
badge: "BEST VALUE",
selected: plan == "yearly",
tap: () => setState(() => plan = "yearly"),
),

const SizedBox(height: 12),

_planCard(
title: "Monthly",
price: "\$15.99 / month",
badge: null,
selected: plan == "monthly",
tap: () => setState(() => plan = "monthly"),
),

const SizedBox(height: 30),

/// 🔥 CTA
GestureDetector(
onTap: startSubscription,
child: Container(
height: 64,
decoration: BoxDecoration(
borderRadius:
BorderRadius.circular(30),
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
"Start Free Trial",
style: TextStyle(
fontSize: 18,
fontWeight:
FontWeight.w800,
),
),
),
),
),

const SizedBox(height: 14),

/// 🔥 TRUST / RISK REVERSAL
const Center(
child: Text(
"30-day free trial • No charge today • Cancel anytime",
style: TextStyle(
color: Colors.white60,
fontSize: 12,
),
),
),

const SizedBox(height: 10),

const Center(
child: Text(
"Used by parents navigating custody with confidence",
style: TextStyle(
color: Colors.white38,
fontSize: 11,
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

Widget _feature(String text) {
return Padding(
padding: const EdgeInsets.only(bottom: 10),
child: Row(
children: [
const Icon(Icons.check, color: Colors.greenAccent),
const SizedBox(width: 10),
Expanded(child: Text(text)),
],
),
);
}

Widget _planCard({
required String title,
required String price,
String? badge,
required bool selected,
required VoidCallback tap,
}) {
return GestureDetector(
onTap: tap,
child: Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: selected
? const Color(0xff3d7cff)
: Colors.white.withOpacity(.06),
borderRadius: BorderRadius.circular(22),
border: badge != null
? Border.all(color: Colors.white, width: 1.5)
: null,
),
child: Row(
children: [
Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Text(title),
if (badge != null) ...[
const SizedBox(width: 6),
Text(
badge,
style: const TextStyle(
fontSize: 10,
color: Colors.yellow,
),
)
]
],
),
const SizedBox(height: 4),
Text(price),
],
),
const Spacer(),
],
),
),
);
}
}
