import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';

class DayIntelligenceScreen extends StatelessWidget {
final DateTime date;

const DayIntelligenceScreen({super.key, required this.date});

Color riskColor(String risk) {
switch (risk) {
case "High":
return PLDesign.danger;
case "Moderate":
return PLDesign.warning;
default:
return PLDesign.success;
}
}

Widget intelligenceCard({
required IconData icon,
required String title,
required Widget child,
}) {
return Container(
margin: const EdgeInsets.only(bottom: 18),
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Icon(icon, color: PLDesign.primary),
const SizedBox(width: 10),
Text(title, style: PLDesign.sectionTitle),
],
),
const SizedBox(height: 16),
child,
],
),
);
}

@override
Widget build(BuildContext context) {
const risk = "Moderate";

return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(
backgroundColor: PLDesign.surface,
title: Text(
"${date.month}/${date.day}/${date.year}",
style: PLDesign.sectionTitle,
),
),
body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// ⭐ COMPLIANCE INTELLIGENCE
intelligenceCard(
icon: Icons.verified_user,
title: "Compliance Intelligence",
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
_stat("Score", "88%"),
_stat("Violations", "1"),
_riskStat(risk),
],
),
),

/// ⭐ EXCHANGE
intelligenceCard(
icon: Icons.swap_horiz,
title: "Exchange",
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
"5:00 PM • Central School Parking Lot",
style: PLDesign.body,
),
const SizedBox(height: 10),
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: PLDesign.warning.withValues(alpha:.15),
borderRadius: BorderRadius.circular(12),
),
child: const Row(
children: [
Icon(Icons.psychology,
color: PLDesign.warning, size: 18),
SizedBox(width: 8),
Expanded(
child: Text(
"Possible late arrival risk detected",
style: TextStyle(color: PLDesign.warning),
),
),
],
),
)
],
),
),

/// ⭐ COMMUNICATION
intelligenceCard(
icon: Icons.chat_bubble_outline,
title: "Communication",
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
_stat("Messages", "2"),
_stat("Flags", "1"),
_stat("Tone Risk", "Medium"),
],
),
),

/// ⭐ EVIDENCE + LEGAL
intelligenceCard(
icon: Icons.gavel,
title: "Legal Readiness",
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
_stat("Evidence", "1"),
_stat("Narrative", "Ready"),
_stat("Export", "Available"),
],
),
),

const SizedBox(height: 12),

/// ⭐ TIMELINE BUTTON
GestureDetector(
onTap: () {},
child: Container(
height: 56,
decoration: const BoxDecoration(
gradient: PLDesign.primaryGradient,
borderRadius: PLDesign.r16,
),
child: const Center(
child: Text(
"Open Full Timeline Replay",
style: PLDesign.buttonText,
),
),
),
),

const SizedBox(height: 40),
],
),
);
}

Widget _stat(String label, String value) {
return Column(
children: [
Text(value, style: PLDesign.statNumber),
const SizedBox(height: 4),
Text(label, style: PLDesign.caption),
],
);
}

Widget _riskStat(String risk) {
return Column(
children: [
Text(
risk,
style: PLDesign.statNumber.copyWith(
color: riskColor(risk),
),
),
const SizedBox(height: 4),
const Text("Risk", style: PLDesign.caption),
],
);
}
}
