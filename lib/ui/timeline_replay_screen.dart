import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';
import 'compliance_forecast_screen.dart';

class TimelineReplayScreen extends StatefulWidget {
const TimelineReplayScreen({super.key});

@override
State<TimelineReplayScreen> createState() => _TimelineReplayScreenState();
}

class _TimelineReplayScreenState extends State<TimelineReplayScreen> {

double speed = 1.0;

final List<Map<String, dynamic>> events = [
{
"title": "Exchange Completed",
"time": "Mar 3 • 5:02 PM",
"type": "exchange"
},
{
"title": "Expense Submitted \$82",
"time": "Mar 4 • 9:11 PM",
"type": "expense"
},
{
"title": "Message Sent",
"time": "Mar 5 • 8:44 AM",
"type": "message"
},
{
"title": "Proposal Accepted",
"time": "Mar 6 • 6:12 PM",
"type": "proposal"
},
];

Color typeColor(String t) {
switch (t) {
case "exchange":
return Colors.cyanAccent;
case "expense":
return Colors.greenAccent;
case "message":
return Colors.purpleAccent;
default:
return Colors.orangeAccent;
}
}

Widget eventCard(Map e) {
return Container(
margin: const EdgeInsets.only(bottom: 16),
padding: const EdgeInsets.all(18),
decoration: PLDesign.elevatedCard, // ⭐ fixed decoration
child: Row(
children: [
Container(
width: 10,
height: 60,
decoration: BoxDecoration(
color: typeColor(e["type"]),
borderRadius: BorderRadius.circular(8),
),
),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(e["title"], style: PLDesign.sectionTitle),
const SizedBox(height: 4),
Text(e["time"], style: PLDesign.caption),
],
),
)
],
),
);
}

Widget aiForecastCard() {
return Container(
padding: const EdgeInsets.all(20),
decoration: PLDesign.aiSurface,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

const Row(
children: [
Icon(Icons.psychology, color: PLDesign.ai),
SizedBox(width: 8),
Text(
"AI Compliance Forecast",
style: PLDesign.sectionTitle,
),
],
),

const SizedBox(height: 10),

const Text(
"Behavior trend suggests elevated exchange timing risk "
"and delayed expense cooperation in upcoming cycle.",
style: PLDesign.body,
),

const SizedBox(height: 16),

PLDesign.primaryButton(
label: "Open Compliance Forecast",
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const ComplianceForecastScreen(),
),
);
},
)

],
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(
title: const Text("Timeline Replay"),
backgroundColor: PLDesign.surface,
),
body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// ⭐ NEW AI FORECAST BLOCK
aiForecastCard(),

const SizedBox(height: 24),

/// SPEED CONTROL
Container(
padding: const EdgeInsets.all(20),
decoration: PLDesign.elevatedCard,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

const Text(
"Replay Speed",
style: PLDesign.sectionTitle,
),

Slider(
value: speed,
min: .5,
max: 3,
divisions: 5,
label: "${speed}x",
onChanged: (v) {
setState(() => speed = v);
},
)
],
),
),

const SizedBox(height: 24),

...events.map(eventCard)

],
),
);
}
}
