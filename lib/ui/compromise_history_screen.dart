import 'package:flutter/material.dart';
import 'recent_activity_timeline_screen.dart';

class CompromiseHistoryScreen extends StatelessWidget {
const CompromiseHistoryScreen({super.key});

Widget historyTile(
String title,
String date,
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
CircleAvatar(
radius: 18,
backgroundColor: color.withOpacity(.2),
child: Icon(Icons.handshake, color: color, size: 18),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
title,
style: const TextStyle(
fontWeight: FontWeight.w800),
),
const SizedBox(height: 4),
Text(
date,
style: const TextStyle(
color: Colors.grey,
fontSize: 12),
)
],
),
),
Text(
status,
style: TextStyle(
color: color,
fontWeight: FontWeight.w700,
),
)
],
),
);
}

Widget statCard(String label, String value, Color color) {
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
label,
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

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff5f6fb),

appBar: AppBar(
title: const Text("Compromise History"),
centerTitle: true,
),

body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// HEADER STATS
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

Icon(Icons.history,
color: Colors.white, size: 34),

SizedBox(width: 14),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
"Compromise Success Rate",
style:
TextStyle(color: Colors.white70),
),
SizedBox(height: 4),
Text(
"68%",
style: TextStyle(
fontSize: 32,
fontWeight: FontWeight.w900,
color: Colors.white,
),
)
],
),
),

Icon(Icons.trending_up,
color: Colors.white)
],
),
),

const SizedBox(height: 20),

Row(
children: [
statCard("Accepted", "12", Colors.green),
const SizedBox(width: 10),
statCard("Rejected", "5", Colors.red),
const SizedBox(width: 10),
statCard("Expired", "3", Colors.orange),
],
),

const SizedBox(height: 24),

const Text(
"Negotiation Timeline",
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800),
),

const SizedBox(height: 12),

historyTile(
"Exchange Time Adjustment",
"Mar 10",
"Accepted",
Colors.green),

historyTile(
"Expense Split Proposal",
"Mar 7",
"Rejected",
Colors.red),

historyTile(
"Weekend Schedule Swap",
"Mar 2",
"Expired",
Colors.orange),

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
"AI Pattern Insight",
style:
TextStyle(fontWeight: FontWeight.w800),
),
SizedBox(height: 8),
Text(
"Proposal acceptance improved after proactive "
"communication attempts. Timing disputes remain "
"the primary negotiation friction point.",
style: TextStyle(
height: 1.4,
color: Colors.black54),
)
],
),
),

const SizedBox(height: 26),

Row(
children: [

Expanded(
child: ElevatedButton(
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const RecentActivityTimelineScreen(),
),
);
},
child:
const Text("Open Timeline Replay"),
),
),

const SizedBox(width: 12),

Expanded(
child: OutlinedButton(
onPressed: () {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text("History export will be available in the export center soon."),
),
);
},
child:
const Text("Export History"),
),
),

],
),

const SizedBox(height: 40),

],
),
);
}
}
