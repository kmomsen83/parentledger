import 'package:flutter/material.dart';

class BehaviorAnalysisScreen extends StatelessWidget {
const BehaviorAnalysisScreen({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff4f6fa),

appBar: AppBar(
backgroundColor: Colors.white,
elevation: 0,
leading: IconButton(
icon: const Icon(Icons.arrow_back, color: Colors.black),
onPressed: () => Navigator.pop(context),
),
title: const Text(
"Behavior Analysis",
style: TextStyle(
color: Colors.black,
fontWeight: FontWeight.w700,
),
),
centerTitle: true,
),

body: SingleChildScrollView(
padding: const EdgeInsets.all(20),
child: Column(
children: [

/// RISK SUMMARY CARD
Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [
Color(0xff2563eb),
Color(0xff4f46e5),
],
),
borderRadius: BorderRadius.circular(22),
),
child: const Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(Icons.psychology,
color: Colors.white, size: 28),
SizedBox(height: 12),
Text(
"Moderate Behavioral Risk",
style: TextStyle(
color: Colors.white,
fontSize: 22,
fontWeight: FontWeight.w800,
),
),
SizedBox(height: 6),
Text(
"Detected increased message hostility + late exchanges",
style: TextStyle(
color: Colors.white70,
),
),
],
),
),

const SizedBox(height: 20),

/// METRIC CARD
_metricCard(
"Hostile Message Tone",
64,
Colors.orange,
Icons.chat_bubble_outline,
),

_metricCard(
"Exchange Compliance",
82,
Colors.green,
Icons.location_on_outlined,
),

_metricCard(
"Proposal Cooperation",
41,
Colors.red,
Icons.handshake_outlined,
),

const SizedBox(height: 20),

/// AI NARRATIVE
Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(18),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.05),
blurRadius: 14,
offset: const Offset(0,6),
)
],
),
child: const Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
"AI Narrative Insight",
style: TextStyle(
fontWeight: FontWeight.w700,
fontSize: 16,
),
),
SizedBox(height: 8),
Text(
"Over the last 30 days communication shows a measurable shift toward reactive responses and reduced compromise acceptance. "
"Custody exchange punctuality remains stable but negotiation sentiment trend is declining.",
style: TextStyle(
color: Colors.grey,
height: 1.5,
),
),
],
),
),

const SizedBox(height: 20),

/// BUTTONS
Row(
children: [
Expanded(
child: _actionButton(
"View Timeline",
Colors.white,
const Color(0xff2563eb),
() {},
),
),
const SizedBox(width: 12),
Expanded(
child: _actionButton(
"Legal Export",
const Color(0xff2563eb),
Colors.white,
() {},
),
),
],
),

const SizedBox(height: 16),

GestureDetector(
onTap: () => Navigator.pop(context),
child: const Text(
"Return to Dashboard",
style: TextStyle(
color: Color(0xff2563eb),
fontWeight: FontWeight.w600,
),
),
)
],
),
),
);
}

Widget _metricCard(
String title, int score, Color color, IconData icon) {
return Container(
margin: const EdgeInsets.only(bottom: 14),
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(18),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.04),
blurRadius: 12,
offset: const Offset(0,6),
)
],
),
child: Row(
children: [
CircleAvatar(
radius: 22,
backgroundColor: color.withOpacity(.12),
child: Icon(icon, color: color),
),
const SizedBox(width: 14),
Expanded(
child: Text(
title,
style: const TextStyle(
fontWeight: FontWeight.w700,
),
),
),
Text(
"$score%",
style: TextStyle(
fontWeight: FontWeight.w800,
color: color,
fontSize: 18,
),
)
],
),
);
}

Widget _actionButton(
String text, Color bg, Color textColor, VoidCallback onTap) {
return GestureDetector(
onTap: onTap,
child: Container(
height: 56,
decoration: BoxDecoration(
color: bg,
borderRadius: BorderRadius.circular(14),
border: Border.all(color: const Color(0xff2563eb)),
),
child: Center(
child: Text(
text,
style: TextStyle(
fontWeight: FontWeight.w700,
color: textColor,
),
),
),
),
);
}
}
