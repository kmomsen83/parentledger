import 'package:flutter/material.dart';

class AiFairnessSuggestionScreen extends StatelessWidget {
const AiFairnessSuggestionScreen({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff3f5fb),

appBar: AppBar(
elevation: 0,
backgroundColor: Colors.transparent,
leading: IconButton(
icon: const Icon(Icons.arrow_back, color: Color(0xff111827)),
onPressed: () => Navigator.pop(context),
),
centerTitle: true,
title: const Text(
"AI Fairness Analysis",
style: TextStyle(
color: Color(0xff111827),
fontWeight: FontWeight.w800,
),
),
),

body: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

/// ⭐ FAIRNESS SCORE HERO
Container(
padding: const EdgeInsets.all(24),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(26),
gradient: const LinearGradient(
colors: [
Color(0xff4f46e5),
Color(0xff1d4ed8),
],
),
boxShadow: [
BoxShadow(
color: const Color(0xff4f46e5).withValues(alpha: .35),
blurRadius: 30,
offset: const Offset(0, 18),
)
],
),
child: const Row(
children: [
Icon(Icons.balance_rounded,
color: Colors.white, size: 36),
SizedBox(width: 16),
Expanded(
child: Text(
"Overall Fairness Score",
style: TextStyle(
color: Colors.white70,
fontWeight: FontWeight.w600,
),
),
),
Text(
"82%",
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w900,
fontSize: 30,
),
)
],
),
),

const SizedBox(height: 28),

/// ⭐ DISTRIBUTION PANEL
const Text(
"Parenting Time Distribution",
style: TextStyle(
fontWeight: FontWeight.w800,
fontSize: 18,
),
),

const SizedBox(height: 14),

Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(22),
gradient: const LinearGradient(
colors: [
Color(0xffffffff),
Color(0xfff8fafc),
],
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: .05),
blurRadius: 22,
offset: const Offset(0, 12),
)
],
),
child: Column(
children: [

_distRow("You", .54, const Color(0xff2563eb)),

const SizedBox(height: 18),

_distRow("Other Parent", .46, const Color(0xff7c3aed)),
],
),
),

const SizedBox(height: 26),

/// ⭐ AI REASONING PANEL
const Text(
"AI Reasoning",
style: TextStyle(
fontWeight: FontWeight.w800,
fontSize: 18,
),
),

const SizedBox(height: 12),

Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(22),
color: Colors.white,
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: .05),
blurRadius: 20,
offset: const Offset(0, 12),
)
],
),
child: const Text(
"Recent schedule proposals increased imbalance slightly. "
"AI recommends redistributing one weekday overnight "
"to maintain long-term fairness and reduce dispute risk.",
style: TextStyle(
height: 1.6,
fontWeight: FontWeight.w500,
color: Color(0xff374151),
),
),
),

const SizedBox(height: 26),

/// ⭐ SUGGESTED COMPROMISE HERO
const Text(
"Suggested Compromise",
style: TextStyle(
fontWeight: FontWeight.w800,
fontSize: 18,
),
),

const SizedBox(height: 12),

Container(
padding: const EdgeInsets.all(22),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(22),
gradient: const LinearGradient(
colors: [
Color(0xff22c55e),
Color(0xff15803d),
],
),
boxShadow: [
BoxShadow(
color: const Color(0xff22c55e).withValues(alpha: .35),
blurRadius: 20,
offset: const Offset(0, 10),
)
],
),
child: const Text(
"Transfer Wednesday overnight exchange "
"to other parent starting next week.",
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w800,
fontSize: 16,
height: 1.4,
),
),
),

const SizedBox(height: 34),

/// ⭐ ACTION BAR
Row(
children: [

Expanded(
child: Container(
height: 60,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(18),
color: Colors.white,
border: Border.all(
color: const Color(0xffe5e7eb),
),
),
child: const Center(
child: Text(
"Counter Suggestion",
style: TextStyle(
fontWeight: FontWeight.w700,
),
),
),
),
),

const SizedBox(width: 14),

Expanded(
child: GestureDetector(
onTap: () {
Navigator.pop(context);
},
child: Container(
height: 60,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(18),
gradient: const LinearGradient(
colors: [
Color(0xff3b82f6),
Color(0xff1d4ed8),
],
),
boxShadow: [
BoxShadow(
color: const Color(0xff2563eb)
.withValues(alpha: .4),
blurRadius: 20,
offset: const Offset(0, 10),
)
],
),
child: const Center(
child: Text(
"Accept AI Proposal",
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w800,
),
),
),
),
),
),
],
)
],
),
),
);
}

Widget _distRow(String label, double value, Color color) {
return Column(
children: [

Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(label,
style: const TextStyle(
fontWeight: FontWeight.w700,
)),
Text("${(value * 100).toInt()}%",
style: TextStyle(
fontWeight: FontWeight.w800,
color: color,
)),
],
),

const SizedBox(height: 8),

ClipRRect(
borderRadius: BorderRadius.circular(10),
child: LinearProgressIndicator(
value: value,
minHeight: 10,
backgroundColor: const Color(0xffe5e7eb),
color: color,
),
),
],
);
}
}
