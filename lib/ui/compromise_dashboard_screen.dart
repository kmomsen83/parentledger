import 'package:flutter/material.dart';

class CompromiseDashboardScreen extends StatelessWidget {
const CompromiseDashboardScreen({super.key});

Widget navCard(
BuildContext context,
IconData icon,
String title,
String subtitle,
VoidCallback tap,
) {
return GestureDetector(
onTap: tap,
child: Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(22),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.05),
blurRadius: 14,
offset: const Offset(0,8),
)
],
),
child: Row(
children: [
CircleAvatar(
radius: 24,
backgroundColor: Colors.blue.withOpacity(.12),
child: Icon(icon, color: Colors.blue),
),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
title,
style: const TextStyle(
fontWeight: FontWeight.w800),
),
const SizedBox(height: 4),
Text(
subtitle,
style: const TextStyle(
color: Colors.grey),
)
],
),
),
const Icon(Icons.chevron_right)
],
),
),
);
}

Widget negotiationTile(
String title,
String status,
Color color,
) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: color.withOpacity(.08),
borderRadius: BorderRadius.circular(18),
),
child: Row(
children: [
Icon(Icons.handshake, color: color),
const SizedBox(width: 12),
Expanded(
child: Text(
title,
style: const TextStyle(
fontWeight: FontWeight.w700),
),
),
Text(
status,
style: TextStyle(
color: color,
fontWeight: FontWeight.w700),
)
],
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff5f6fb),

appBar: AppBar(
title: const Text("Compromise Center"),
centerTitle: true,
),

body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// SCORE HEADER
Container(
padding: const EdgeInsets.all(22),
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [
Color(0xff4A6CF7),
Color(0xff7A8BFF),
],
),
borderRadius: BorderRadius.circular(26),
),
child: const Row(
children: [

Icon(Icons.balance,
color: Colors.white, size: 34),

SizedBox(width: 14),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
"Compromise Health",
style:
TextStyle(color: Colors.white70),
),
SizedBox(height: 4),
Text(
"76%",
style: TextStyle(
fontSize: 32,
fontWeight: FontWeight.w900,
color: Colors.white,
),
)
],
),
),

Icon(Icons.psychology,
color: Colors.white)
],
),
),

const SizedBox(height: 22),

navCard(
context,
Icons.psychology,
"AI Fairness Engine",
"View suggested compromise",
() {},
),

const SizedBox(height: 12),

navCard(
context,
Icons.auto_graph,
"Compliance Forecast",
"Predict future cooperation",
() {},
),

const SizedBox(height: 12),

navCard(
context,
Icons.history,
"Compliance History",
"Review past compromise patterns",
() {},
),

const SizedBox(height: 12),

navCard(
context,
Icons.description,
"Compliance Report",
"Generate legal narrative",
() {},
),

const SizedBox(height: 26),

const Text(
"Active Negotiations",
style: TextStyle(
fontWeight: FontWeight.w800,
fontSize: 18),
),

const SizedBox(height: 12),

negotiationTile(
"Schedule Adjustment",
"Pending",
Colors.orange),

negotiationTile(
"Expense Split Discussion",
"In Progress",
Colors.blue),

const SizedBox(height: 26),

/// AI BLOCK
Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(22),
),
child: const Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
"AI Compromise Insight",
style:
TextStyle(fontWeight: FontWeight.w800),
),
SizedBox(height: 8),
Text(
"Recent proposal acceptance trends "
"indicate improved flexibility. "
"Maintaining proactive negotiation "
"may increase compliance trajectory.",
style: TextStyle(
color: Colors.black54,
height: 1.4),
)
],
),
),

const SizedBox(height: 40),

],
),
);
}
}
