import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';

import 'proposal_detail_screen.dart';
import 'active_negotiation_screen.dart';
import 'create_proposal_screen.dart';

class ProposalsListScreen extends StatefulWidget {
const ProposalsListScreen({super.key});

@override
State<ProposalsListScreen> createState() => _ProposalsListScreenState();
}

class _ProposalsListScreenState extends State<ProposalsListScreen> {

final List<Map<String, dynamic>> proposals = [
{
"title": "Adjust Friday Exchange",
"child": "Jordan",
"status": "Pending",
"fairness": "balanced",
"time": "2 hrs ago"
},
{
"title": "Holiday Schedule Change",
"child": "Ava",
"status": "Needs Response",
"fairness": "unfair",
"time": "Yesterday"
},
{
"title": "Expense Payment Timeline",
"child": "Jordan",
"status": "Accepted",
"fairness": "fair",
"time": "Mon"
},
];

Color statusColor(String s) {
switch (s) {
case "Accepted":
return PLDesign.success;
case "Needs Response":
return PLDesign.warning;
default:
return PLDesign.primary;
}
}

Color fairnessColor(String f) {
switch (f) {
case "unfair":
return PLDesign.danger;
case "balanced":
return PLDesign.warning;
default:
return PLDesign.success;
}
}

void goDetail(Map<String,dynamic> p) {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => ProposalDetailScreen(proposal: p),
),
);
}

void goNegotiation(Map<String,dynamic> p) {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => ActiveNegotiationScreen(proposal: p),
),
);
}

Widget proposalCard(Map<String, dynamic> p) {
return GestureDetector(
onTap: () => goDetail(p),
child: Container(
margin: const EdgeInsets.only(bottom: 18),
padding: const EdgeInsets.all(20),
decoration: PLDesign.elevatedCard,
child: Column(
children: [

/// HEADER
Row(
children: [

Container(
height: 46,
width: 46,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(14),
gradient: PLDesign.primaryGradient,
),
child: Center(
child: Text(
p["child"][0],
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w800,
),
),
),
),

const SizedBox(width: 14),

Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

Text(
p["title"],
style: PLDesign.timelineTitle,
),

const SizedBox(height: 4),

Text(
p["child"],
style: PLDesign.caption,
),
],
),
),

Column(
crossAxisAlignment: CrossAxisAlignment.end,
children: [

Container(
padding: const EdgeInsets.symmetric(
horizontal: 10, vertical: 6),
decoration: BoxDecoration(
color: statusColor(p["status"]).withOpacity(.12),
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: statusColor(p["status"]).withOpacity(.35),
),
),
child: Text(
p["status"],
style: TextStyle(
color: statusColor(p["status"]),
fontWeight: FontWeight.w700,
fontSize: 12,
),
),
),

const SizedBox(height: 6),

Text(
p["time"],
style: const TextStyle(
color: Colors.white38,
fontSize: 11,
),
),
],
)
],
),

const SizedBox(height: 16),

/// AI FAIRNESS
Container(
padding: const EdgeInsets.all(12),
decoration: PLDesign.aiSurface,
child: Row(
children: [
const Icon(Icons.psychology,
color: PLDesign.ai, size: 18),
const SizedBox(width: 8),
Expanded(
child: Text(
"AI fairness signal: ${p["fairness"]}",
style: TextStyle(
color: fairnessColor(p["fairness"]),
fontWeight: FontWeight.w600,
),
),
),
],
),
),

const SizedBox(height: 16),

/// ACTIONS
Row(
children: [

Expanded(
child: OutlinedButton(
onPressed: () => goDetail(p),
style: OutlinedButton.styleFrom(
foregroundColor: Colors.white,
side: const BorderSide(color: PLDesign.border),
),
child: const Text("View Details"),
),
),

const SizedBox(width: 10),

Expanded(
child: ElevatedButton(
onPressed: () => goNegotiation(p),
style: ElevatedButton.styleFrom(
backgroundColor: PLDesign.primary,
),
child: const Text("Respond"),
),
),

],
)

],
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: PLDesign.background,

appBar: AppBar(
title: const Text("Proposals"),
backgroundColor: PLDesign.surface,
elevation: 0,
actions: [

IconButton(
icon: const Icon(Icons.filter_list),
onPressed: () {},
),

IconButton(
icon: const Icon(Icons.add),
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const CreateProposalScreen(),
),
);
},
),

],
),

body: ListView.builder(
padding: const EdgeInsets.all(22),
itemCount: proposals.length,
itemBuilder: (c, i) => proposalCard(proposals[i]),
),
);
}
}
