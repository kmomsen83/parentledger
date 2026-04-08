import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';

class CourtTimelineExportScreen extends StatelessWidget {
final Map<String, dynamic> proposal;

const CourtTimelineExportScreen({
super.key,
required this.proposal,
});

List<Map<String, String>> buildEvents() {
return [
{
"time": "10:22 AM",
"text": "Proposal created by Parent A"
},
{
"time": "10:23 AM",
"text": "AI fairness analysis generated (${proposal["fairness"]})"
},
{
"time": "2:01 PM",
"text": "Proposal viewed by Parent B"
},
{
"time": "Next Day",
"text": "No response recorded"
},
];
}

String aiNarrative() {
return
"On ${proposal["time"]}, a proposal titled '${proposal["title"]}' "
"was submitted concerning ${proposal["child"]}. "
"AI fairness evaluation classified the proposal as '${proposal["fairness"]}'. "
"Subsequent timeline analysis indicates delayed engagement from the other parent.";
}

Widget header() {
return PLDesign.cardBox(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
"Legal Timeline Export",
style: PLDesign.sectionTitle,
),
const SizedBox(height: 8),
Text("Proposal: ${proposal["title"]}", style: PLDesign.body),
Text("Child: ${proposal["child"]}", style: PLDesign.body),
Text("Status: ${proposal["status"]}", style: PLDesign.body),
],
),
);
}

Widget narrativeCard() {
return Container(
padding: const EdgeInsets.all(20),
decoration: PLDesign.legalCard,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Row(
children: [
Icon(Icons.psychology, color: PLDesign.ai),
SizedBox(width: 8),
Text("AI Legal Narrative", style: PLDesign.sectionTitle),
],
),
const SizedBox(height: 12),
Text(
aiNarrative(),
style: PLDesign.legalBody,
),
],
),
);
}

Widget eventRow(Map<String, String> e) {
return Container(
margin: const EdgeInsets.only(bottom: 14),
padding: const EdgeInsets.all(16),
decoration: PLDesign.exportTileDecoration,
child: Row(
children: [
SizedBox(
width: 90,
child: Text(
e["time"]!,
style: PLDesign.sectionTitle,
),
),
Expanded(
child: Text(
e["text"]!,
style: PLDesign.body,
),
)
],
),
);
}

Widget exportButtons() {
return Column(
children: [
PLDesign.primaryButton(
label: "Export PDF",
onTap: () {},
),
const SizedBox(height: 12),
GestureDetector(
onTap: () {},
child: Container(
height: 54,
decoration: BoxDecoration(
borderRadius: PLDesign.r16,
border: Border.all(color: PLDesign.border),
),
child: const Center(
child: Text(
"Share With Attorney",
style: PLDesign.secondaryButtonText,
),
),
),
),
],
);
}

@override
Widget build(BuildContext context) {
final events = buildEvents();

return Scaffold(
backgroundColor: PLDesign.background,
body: PLDesign.screen(
title: "Court Timeline Export",
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
header(),
const SizedBox(height: 24),
narrativeCard(),
const SizedBox(height: 28),
const Text("Timeline Evidence", style: PLDesign.sectionTitle),
const SizedBox(height: 12),
...events.map(eventRow),
const SizedBox(height: 32),
exportButtons(),
const SizedBox(height: 40),
],
),
),
);
}
}
