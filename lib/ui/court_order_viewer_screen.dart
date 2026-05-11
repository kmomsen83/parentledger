import 'package:flutter/material.dart';

class CourtOrderViewerScreen extends StatelessWidget {
const CourtOrderViewerScreen({super.key});

Widget infoChip(String label) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: Colors.grey.shade200,
borderRadius: BorderRadius.circular(8),
),
child: Text(
label,
style: const TextStyle(
fontSize: 12,
fontWeight: FontWeight.w600),
),
);
}

Widget clauseTile(
String title,
String body,
bool risk,
) {
return Container(
margin: const EdgeInsets.only(bottom: 14),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color:
risk ? Colors.red.withValues(alpha:.08) : Colors.white,
borderRadius: BorderRadius.circular(18),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha:.04),
blurRadius: 10)
],
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [

Row(
children: [
Expanded(
child: Text(
title,
style: const TextStyle(
fontWeight: FontWeight.w800),
),
),
if (risk)
const Icon(Icons.warning,
color: Colors.red, size: 18)
],
),

const SizedBox(height: 8),

Text(
body,
style: const TextStyle(
color: Colors.black54,
height: 1.4),
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
title: const Text("Court Order"),
centerTitle: true,
),

body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// HEADER
Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(22),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [

const Text(
"Custody Agreement Order",
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.w900),
),

const SizedBox(height: 6),

const Text(
"Montgomery County Family Court",
style: TextStyle(
color: Colors.grey),
),

const SizedBox(height: 12),

Row(
children: [
infoChip("Effective Mar 2024"),
const SizedBox(width: 8),
infoChip("Active"),
const SizedBox(width: 8),
infoChip("Shared Custody"),
],
)
],
),
),

const SizedBox(height: 20),

const Text(
"Order Clauses",
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800),
),

const SizedBox(height: 12),

clauseTile(
"Exchange Timing",
"Parents must complete custody exchange "
"no later than 5:00 PM on scheduled days.",
true,
),

clauseTile(
"Holiday Schedule",
"Alternating major holidays between parents.",
false,
),

clauseTile(
"Expense Responsibility",
"Medical and school expenses split equally.",
false,
),

const SizedBox(height: 24),

/// AI INTERPRETATION
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
"AI Interpretation",
style:
TextStyle(fontWeight: FontWeight.w800),
),
SizedBox(height: 8),
Text(
"Recent late exchanges may place the "
"user at moderate violation risk under "
"Clause 1. Proactive confirmation is advised.",
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
child: const Text("Open Timeline"),
),
),

const SizedBox(width: 12),

Expanded(
child: OutlinedButton(
onPressed: () {},
child: const Text("Export Order"),
),
),

],
),

const SizedBox(height: 40),

],
),

floatingActionButton: FloatingActionButton(
backgroundColor: Colors.deepPurple,
onPressed: () {},
child: const Icon(Icons.note_add),
),
);
}
}
