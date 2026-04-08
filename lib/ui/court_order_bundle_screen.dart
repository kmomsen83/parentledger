import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';

class CourtOrderBundleScreen extends StatefulWidget {
const CourtOrderBundleScreen({super.key});

@override
State<CourtOrderBundleScreen> createState() =>
_CourtOrderBundleScreenState();
}

class _CourtOrderBundleScreenState
extends State<CourtOrderBundleScreen> {

final List<Map<String, dynamic>> clauses = [
{
"title": "Friday Exchange 5PM",
"status": "Compliant",
"events": 6,
"risk": "low"
},
{
"title": "Holiday Rotation",
"status": "Violation",
"events": 2,
"risk": "high"
},
{
"title": "Expense Reimbursement 30 Days",
"status": "At Risk",
"events": 4,
"risk": "medium"
},
];

Color statusColor(String s) {
switch (s) {
case "Violation":
return PLDesign.danger;
case "At Risk":
return PLDesign.warning;
default:
return PLDesign.success;
}
}

Color riskColor(String r) {
switch (r) {
case "high":
return PLDesign.danger;
case "medium":
return PLDesign.warning;
default:
return PLDesign.success;
}
}

Widget clauseCard(Map c) {
return Container(
margin: const EdgeInsets.only(bottom: 16),
padding: const EdgeInsets.all(20),
decoration: PLDesign.exportTileDecoration,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

Row(
children: [

Expanded(
child: Text(
c["title"],
style: PLDesign.sectionTitle,
),
),

Container(
padding: const EdgeInsets.symmetric(
horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: statusColor(c["status"]).withOpacity(.15),
borderRadius: BorderRadius.circular(20),
),
child: Text(
c["status"],
style: TextStyle(
color: statusColor(c["status"]),
fontWeight: FontWeight.w700,
),
),
)
],
),

const SizedBox(height: 14),

Row(
children: [

const Icon(
Icons.timeline,
color: PLDesign.textMuted,
size: 18,
),

const SizedBox(width: 6),

Text(
"${c["events"]} linked events",
style: PLDesign.caption,
),

const Spacer(),

Icon(
Icons.psychology,
color: riskColor(c["risk"]),
size: 18,
),

const SizedBox(width: 6),

Text(
"Risk ${c["risk"]}",
style: TextStyle(
color: riskColor(c["risk"]),
fontWeight: FontWeight.w600,
),
),
],
),

const SizedBox(height: 16),

Row(
children: [

Expanded(
child: GestureDetector(
onTap: () {
/// ⭐ jump to timeline replay filtered
},
child: Container(
height: 48,
decoration: BoxDecoration(
borderRadius: PLDesign.r16,
border: Border.all(color: PLDesign.border),
),
child: const Center(
child: Text(
"View Timeline",
style: PLDesign.secondaryButtonText,
),
),
),
),
),

const SizedBox(width: 10),

Expanded(
child: PLDesign.primaryButton(
label: "Open Evidence",
onTap: () {
/// ⭐ view violation details
},
),
),
],
)
],
),
);
}

Widget aiSummaryCard() {
return Container(
padding: const EdgeInsets.all(22),
decoration: PLDesign.legalCard,
child: const Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

Row(
children: [
Icon(Icons.gavel, color: PLDesign.primary),
SizedBox(width: 8),
Text(
"AI Legal Summary",
style: PLDesign.sectionTitle,
),
],
),

SizedBox(height: 10),

Text(
"2 potential violations detected. "
"Holiday clause shows non-compliance pattern. "
"Exchange timing remains highly compliant.",
style: PLDesign.legalBody,
)
],
),
);
}

Widget exportButton() {
return Padding(
padding: const EdgeInsets.only(top: 10),
child: PLDesign.primaryButton(
label: "Generate Court Order Bundle",
onTap: () {
/// ⭐ export full bundle
},
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: PLDesign.background,
body: PLDesign.screen(
title: "Court Order Bundle",
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

aiSummaryCard(),

const SizedBox(height: 28),

const Text(
"Linked Clauses",
style: PLDesign.sectionTitle,
),

const SizedBox(height: 12),

...clauses.map((c) => clauseCard(c)),

exportButton(),

const SizedBox(height: 40),

],
),
),
);
}
}
