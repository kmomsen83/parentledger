import 'package:flutter/material.dart';

class ComplianceReportScreen extends StatelessWidget {
const ComplianceReportScreen({super.key});

Widget metricTile(String title, String value, Color color) {
return Expanded(
child: Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: color.withOpacity(.08),
borderRadius: BorderRadius.circular(18),
),
child: Column(
children: [
Text(
value,
style: TextStyle(
fontSize: 22,
fontWeight: FontWeight.w900,
color: color),
),
const SizedBox(height: 4),
Text(
title,
textAlign: TextAlign.center,
style: const TextStyle(
color: Colors.black54,
fontWeight: FontWeight.w600),
)
],
),
),
);
}

Widget violationRow(
String title, String date, Color color) {
return Container(
margin: const EdgeInsets.only(bottom: 10),
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: color.withOpacity(.08),
borderRadius: BorderRadius.circular(14),
),
child: Row(
children: [
Icon(Icons.warning,
color: color, size: 18),
const SizedBox(width: 10),
Expanded(
child: Text(
title,
style: const TextStyle(
fontWeight: FontWeight.w700),
),
),
Text(date,
style:
const TextStyle(color: Colors.grey))
],
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff5f6fb),

appBar: AppBar(
title: const Text("Compliance Report"),
centerTitle: true,
),

body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// HEADER
Container(
padding: const EdgeInsets.all(22),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(24),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.05),
blurRadius: 12,
)
],
),
child: const Row(
children: [

CircleAvatar(
radius: 26,
backgroundColor: Colors.green,
child: Icon(Icons.verified,
color: Colors.white),
),

SizedBox(width: 16),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
"Overall Compliance",
style: TextStyle(
color: Colors.grey),
),
SizedBox(height: 4),
Text(
"91%",
style: TextStyle(
fontSize: 32,
fontWeight:
FontWeight.w900),
)
],
),
),

Text(
"Last 30 Days",
style:
TextStyle(color: Colors.grey),
)
],
),
),

const SizedBox(height: 20),

/// METRICS GRID
Row(
children: [
metricTile("Exchanges", "12",
Colors.blue),
const SizedBox(width: 10),
metricTile("Violations", "1",
Colors.red),
const SizedBox(width: 10),
metricTile("Proposals", "3",
Colors.orange),
],
),

const SizedBox(height: 10),

Row(
children: [
metricTile("Expenses", "5",
Colors.green),
const SizedBox(width: 10),
metricTile("Messages", "48",
Colors.purple),
const SizedBox(width: 10),
metricTile("Documents", "2",
Colors.teal),
],
),

const SizedBox(height: 24),

const Text(
"Violation Summary",
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800),
),

const SizedBox(height: 12),

violationRow(
"Late Exchange",
"Mar 4",
Colors.red),

const SizedBox(height: 24),

/// AI SUMMARY
Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(20),
),
child: const Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
"AI Compliance Narrative",
style: TextStyle(
fontWeight: FontWeight.w800),
),
SizedBox(height: 8),
Text(
"Overall compliance remains strong. "
"One exchange delay occurred but was "
"resolved without escalation. "
"Expense cooperation and messaging "
"tone stability improved compared "
"to prior reporting period.",
style: TextStyle(
height: 1.4,
color: Colors.black54),
)
],
),
),

const SizedBox(height: 24),

Row(
children: [

Expanded(
child: ElevatedButton(
onPressed: () {},
child:
const Text("Open Timeline"),
),
),

const SizedBox(width: 12),

Expanded(
child: OutlinedButton(
onPressed: () {},
child:
const Text("Export Report"),
),
),
],
),

const SizedBox(height: 40)

],
),
);
}
}
