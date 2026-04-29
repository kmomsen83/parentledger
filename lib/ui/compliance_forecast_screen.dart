import 'package:flutter/material.dart';
import 'recent_activity_timeline_screen.dart';

class ComplianceForecastScreen extends StatelessWidget {
const ComplianceForecastScreen({super.key});

Widget riskEvent(String title, String time, Color color) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: color.withOpacity(.12),
borderRadius: BorderRadius.circular(18),
),
child: Row(
children: [
CircleAvatar(
radius: 18,
backgroundColor: color.withOpacity(.2),
child: Icon(Icons.warning, color: color, size: 18),
),
const SizedBox(width: 12),
Expanded(
child: Text(
title,
style: const TextStyle(
fontWeight: FontWeight.w700,
),
),
),
Text(
time,
style: const TextStyle(color: Colors.grey),
)
],
),
);
}

Widget forecastBar(String label, double value, Color color) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(label,
style: const TextStyle(
fontWeight: FontWeight.w600,
color: Colors.black54)),
const SizedBox(height: 6),
ClipRRect(
borderRadius: BorderRadius.circular(10),
child: LinearProgressIndicator(
value: value,
minHeight: 12,
backgroundColor: Colors.grey.shade200,
valueColor: AlwaysStoppedAnimation(color),
),
),
const SizedBox(height: 14),
],
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff5f6fb),

appBar: AppBar(
title: const Text("Compliance Forecast"),
centerTitle: true,
),

body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// FORECAST HEADER
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

Icon(Icons.auto_graph,
color: Colors.white, size: 36),

SizedBox(width: 16),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
"Projected Compliance",
style: TextStyle(
color: Colors.white70),
),
SizedBox(height: 4),
Text(
"84%",
style: TextStyle(
fontSize: 34,
fontWeight: FontWeight.w900,
color: Colors.white,
),
)
],
),
),

Icon(Icons.psychology,
color: Colors.white)
],
),
),

const SizedBox(height: 24),

const Text(
"Risk Drivers",
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800),
),

const SizedBox(height: 14),

forecastBar(
"Message Tone Volatility", .65, Colors.orange),

forecastBar(
"Exchange Timing Risk", .35, Colors.green),

forecastBar(
"Proposal Disputes", .52, Colors.blue),

const SizedBox(height: 20),

const Text(
"Upcoming Risk Windows",
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800),
),

const SizedBox(height: 12),

riskEvent(
"Friday Exchange Delay Probability",
"Mar 15",
Colors.orange),

riskEvent(
"Expense Dispute Likely",
"Mar 18",
Colors.red),

const SizedBox(height: 20),

/// AI RECOMMENDATION CARD
Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(22),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.05),
blurRadius: 14)
],
),
child: const Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
"AI Recommendation",
style: TextStyle(
fontWeight: FontWeight.w800),
),
SizedBox(height: 8),
Text(
"Proactively confirm exchange timing and "
"reduce reactive messaging to improve "
"projected compliance trajectory.",
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
child: const Text(
"Open Timeline Replay"),
),
),

const SizedBox(width: 12),

Expanded(
child: OutlinedButton(
onPressed: () {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text("Forecast export will be available in the export center soon."),
),
);
},
child: const Text(
"Export Forecast"),
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
