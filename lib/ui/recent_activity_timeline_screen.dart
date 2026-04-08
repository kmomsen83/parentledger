import 'package:flutter/material.dart';

class RecentActivityTimelineScreen extends StatelessWidget {
const RecentActivityTimelineScreen({super.key});

Widget activityTile(
IconData icon,
String title,
String time,
Color color,
) {
return Container(
margin: const EdgeInsets.only(bottom: 14),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(18),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: .05),
blurRadius: 12,
offset: const Offset(0, 6),
)
],
),
child: Row(
children: [
CircleAvatar(
radius: 24,
backgroundColor: color.withValues(alpha: .12),
child: Icon(icon, color: color),
),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(title,
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 15)),
const SizedBox(height: 4),
Text(time,
style: const TextStyle(
color: Colors.black45,
fontSize: 13)),
],
),
),
],
),
);
}

Widget dayHeader(String label) {
return Padding(
padding: const EdgeInsets.symmetric(vertical: 14),
child: Text(label,
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 16)),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff5f6fb),
appBar: AppBar(
title: const Text("Recent Activity"),
backgroundColor: Colors.white,
foregroundColor: Colors.black,
elevation: 0,
),
body: ListView(
padding: const EdgeInsets.all(16),
children: [

dayHeader("Today"),

activityTile(
Icons.chat,
"New message received",
"10:22 AM",
Colors.blue),

activityTile(
Icons.attach_money,
"Expense submitted",
"9:14 AM",
Colors.orange),

dayHeader("Yesterday"),

activityTile(
Icons.location_pin,
"Exchange completed",
"5:02 PM",
Colors.green),

activityTile(
Icons.handshake,
"Proposal accepted",
"2:40 PM",
Colors.purple),

],
),
);
}
}
