import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';

class CustodyRiskAlertDetailScreen extends StatelessWidget {
const CustodyRiskAlertDetailScreen({super.key});

Widget factorTile(String text) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
padding: const EdgeInsets.all(16),
decoration: PLDesign.alertDanger,
child: Row(
children: [
const Icon(Icons.warning_amber_rounded,
color: PLDesign.danger, size: 20),
const SizedBox(width: 12),
Expanded(
child: Text(
text,
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w600),
),
)
],
),
);
}

Widget actionButton(
String text,
Color bg,
Color fg,
VoidCallback tap,
) {
return Expanded(
child: GestureDetector(
onTap: tap,
child: Container(
height: 54,
decoration: BoxDecoration(
gradient: bg == PLDesign.primary
? PLDesign.primaryGradient
: null,
color: bg == PLDesign.primary ? null : bg,
borderRadius: BorderRadius.circular(16),
border: Border.all(
color: bg == Colors.transparent
? PLDesign.border
: bg.withOpacity(.4)),
),
child: Center(
child: Text(
text,
style: TextStyle(
color: fg,
fontWeight: FontWeight.w700),
),
),
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: PLDesign.background,

appBar: AppBar(
title: const Text("Custody Risk Alert"),
backgroundColor: PLDesign.surface,
),

body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// ⭐ ELITE ALERT HEADER
Container(
padding: const EdgeInsets.all(26),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [
PLDesign.danger.withOpacity(.9),
PLDesign.warning.withOpacity(.9),
],
),
borderRadius: PLDesign.r20,
boxShadow: [
BoxShadow(
color: PLDesign.danger.withOpacity(.35),
blurRadius: 40,
spreadRadius: 2,
)
],
),
child: const Row(
children: [
Icon(Icons.gpp_bad,
color: Colors.white, size: 40),
SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
"High Violation Risk",
style:
TextStyle(color: Colors.white70),
),
SizedBox(height: 6),
Text(
"Late Exchange Probability 68%",
style: TextStyle(
fontSize: 24,
fontWeight: FontWeight.w900,
color: Colors.white,
),
)
],
),
)
],
),
),

const SizedBox(height: 26),

const Text(
"Risk Drivers",
style: PLDesign.sectionTitle,
),

const SizedBox(height: 14),

factorTile("Recent delayed exchanges"),
factorTile("Unconfirmed pickup location"),
factorTile("Escalating message tone"),

const SizedBox(height: 26),

/// ⭐ CLAUSE CARD
Container(
padding: const EdgeInsets.all(20),
decoration: PLDesign.elevatedCard,
child: const Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
"Relevant Court Clause",
style:
TextStyle(
fontWeight: FontWeight.w800,
color: Colors.white),
),
SizedBox(height: 10),
Text(
"Custody exchanges must occur by 5:00 PM "
"unless mutually agreed otherwise.",
style: PLDesign.legalBody,
)
],
),
),

const SizedBox(height: 22),

/// ⭐ AI ACTION SURFACE
Container(
padding: const EdgeInsets.all(20),
decoration: PLDesign.aiSurface,
child: const Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Icon(Icons.psychology,
color: PLDesign.ai),
SizedBox(width: 8),
Text(
"AI Recommended Action",
style:
TextStyle(
fontWeight: FontWeight.w800,
color: Colors.white),
),
],
),
SizedBox(height: 10),
Text(
"Confirm exchange timing and location "
"proactively to reduce violation probability.",
style: PLDesign.legalBody,
)
],
),
),

const SizedBox(height: 28),

/// ⭐ ACTION ROW 1
Row(
children: [

actionButton(
"Message",
PLDesign.primary,
Colors.white,
() {}),

const SizedBox(width: 12),

actionButton(
"Open Timeline",
Colors.transparent,
Colors.white,
() {}),

],
),

const SizedBox(height: 12),

/// ⭐ ACTION ROW 2
Row(
children: [

actionButton(
"Confirm Exchange",
PLDesign.success,
Colors.white,
() {}),

const SizedBox(width: 12),

actionButton(
"Mark Resolved",
PLDesign.border,
Colors.white,
() {}),

],
),

const SizedBox(height: 50)

],
),
);
}
}
