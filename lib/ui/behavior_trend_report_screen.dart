import 'package:flutter/material.dart';

class BehaviorTrendReportScreen extends StatelessWidget {
const BehaviorTrendReportScreen({super.key});

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
"Behavior Trend Report",
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

/// TREND GRAPH CARD
Container(
height: 220,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(22),
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
"Communication Sentiment Trend",
style: TextStyle(
fontWeight: FontWeight.w700,
fontSize: 16,
),
),
SizedBox(height: 16),

Expanded(
child: Center(
child: Text(
"Graph Placeholder",
style: TextStyle(
color: Colors.grey,
),
),
),
)
],
),
),

const SizedBox(height: 20),

/// KPI ROW
Row(
children: [

Expanded(
child: _kpiCard(
"Hostility Index",
"↑ 12%",
Colors.red,
),
),

const SizedBox(width: 12),

Expanded(
child: _kpiCard(
"Cooperation",
"↓ 8%",
Colors.orange,
),
),

],
),

const SizedBox(height: 12),

Row(
children: [

Expanded(
child: _kpiCard(
"Exchange Reliability",
"92%",
Colors.green,
),
),

const SizedBox(width: 12),

Expanded(
child: _kpiCard(
"Proposal Acceptance",
"41%",
Colors.blue,
),
),

],
),

const SizedBox(height: 20),

/// AI SUMMARY
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
"AI Behavioral Summary",
style: TextStyle(
fontWeight: FontWeight.w700,
),
),
SizedBox(height: 8),
Text(
"Over the last 60 days communication sentiment has shifted negatively. "
"Compromise responsiveness decreased while emotional escalation increased. "
"Exchange punctuality remains strong suggesting logistical stability but relational strain.",
style: TextStyle(
color: Colors.grey,
height: 1.5,
),
),
],
),
),

const SizedBox(height: 20),

/// ACTION BUTTONS
Row(
children: [

Expanded(
child: _actionButton(
"Export Legal Report",
const Color(0xff2563eb),
Colors.white,
() {},
),
),

const SizedBox(width: 12),

Expanded(
child: _actionButton(
"View Timeline",
Colors.white,
const Color(0xff2563eb),
() {},
),
),

],
),

const SizedBox(height: 18),

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

Widget _kpiCard(String title, String value, Color color) {
return Container(
padding: const EdgeInsets.all(16),
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
child: Column(
children: [
Text(
title,
style: const TextStyle(
color: Colors.grey,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 8),
Text(
value,
style: TextStyle(
fontSize: 22,
fontWeight: FontWeight.w800,
color: color,
),
)
],
),
);
}

Widget _actionButton(
String text,
Color bg,
Color textColor,
VoidCallback onTap,
) {
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
