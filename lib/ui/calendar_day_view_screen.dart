import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';

class CalendarDayViewScreen extends StatelessWidget {
final DateTime date;

const CalendarDayViewScreen({super.key, required this.date});

String get title =>
"${date.month}/${date.day}/${date.year}";

Widget timelineTile(
IconData icon,
String title,
String time,
Color color,
) {
return Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: Row(
children: [

Container(
height: 44,
width: 44,
decoration: BoxDecoration(
color: color.withOpacity(.15),
borderRadius: BorderRadius.circular(12),
),
child: Icon(icon, color: color),
),

const SizedBox(width: 16),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
title,
style: PLDesign.sectionTitle,
),
const SizedBox(height: 4),
Text(
time,
style: PLDesign.caption,
),
],
),
),

const Icon(Icons.chevron_right,
color: Colors.white54)
],
),
);
}

Widget actionButton(
IconData icon,
String label,
VoidCallback tap,
) {
return Expanded(
child: GestureDetector(
onTap: tap,
child: Container(
padding:
const EdgeInsets.symmetric(vertical: 20),
decoration: BoxDecoration(
gradient: PLDesign.primaryGradient,
borderRadius: PLDesign.r20,
boxShadow: PLDesign.glowShadow,
),
child: Column(
children: [
Icon(icon, color: Colors.white),
const SizedBox(height: 8),
Text(
label,
style: PLDesign.caption
.copyWith(color: Colors.white),
)
],
),
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: Container(
decoration: PLDesign.screenGradient,
child: SafeArea(
child: ListView(
padding:
const EdgeInsets.fromLTRB(24, 28, 24, 24),
children: [

Row(
children: [
IconButton(
onPressed: () =>
Navigator.pop(context),
icon:
const Icon(Icons.arrow_back_ios),
),
Text(title,
style: PLDesign.pageTitle),
],
),

const SizedBox(height: 24),

/// AI SUMMARY
Container(
padding: const EdgeInsets.all(22),
decoration: const BoxDecoration(
gradient: PLDesign.primaryGradient,
borderRadius: PLDesign.r20,
boxShadow: PLDesign.softShadow,
),
child: const Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [

Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
"Compliance Risk",
style: TextStyle(
color: Colors.white70),
),
SizedBox(height: 6),
Text(
"LOW",
style: TextStyle(
fontSize: 26,
color: Colors.white,
fontWeight:
FontWeight.bold),
),
],
),

Icon(Icons.auto_awesome,
color: Colors.white,
size: 36)
],
),
),

const SizedBox(height: 28),

const Text("Timeline",
style: PLDesign.sectionTitle),

const SizedBox(height: 16),

timelineTile(
Icons.child_care,
"Custody Exchange",
"5:00 PM",
PLDesign.primary,
),

const SizedBox(height: 12),

timelineTile(
Icons.chat_bubble_outline,
"Messages Logged",
"2 Conversations",
PLDesign.success,
),

const SizedBox(height: 12),

timelineTile(
Icons.warning_amber_rounded,
"Behavior Flag",
"Tone escalation detected",
PLDesign.warning,
),

const SizedBox(height: 28),

const Text("Quick Actions",
style: PLDesign.sectionTitle),

const SizedBox(height: 16),

Row(
children: [

actionButton(
Icons.timeline,
"Replay",
() {}),

const SizedBox(width: 12),

actionButton(
Icons.add,
"Evidence",
() {}),

const SizedBox(width: 12),

actionButton(
Icons.message,
"Message",
() {}),
],
),

const SizedBox(height: 40),
],
),
),
),
);
}
}
