import 'package:flutter/material.dart';

class NotificationsCenterScreen extends StatefulWidget {
const NotificationsCenterScreen({super.key});

@override
State<NotificationsCenterScreen> createState() =>
_NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {

final List<Map<String, dynamic>> notifications = [
{
"title": "Exchange Reminder",
"desc": "Pickup today at 5:00 PM",
"time": "5m ago",
"color": Colors.blue,
"unread": true
},
{
"title": "New Message",
"desc": "Mom sent a new message",
"time": "12m ago",
"color": Colors.indigo,
"unread": true
},
{
"title": "Expense Submitted",
"desc": "\$142.50 waiting approval",
"time": "1h ago",
"color": Colors.green,
"unread": false
},
{
"title": "AI Tone Alert",
"desc": "Recent message may escalate conflict",
"time": "3h ago",
"color": Colors.red,
"unread": false
},
{
"title": "Legal Export Ready",
"desc": "Timeline prepared for download",
"time": "Yesterday",
"color": Colors.orange,
"unread": false
},
];

Widget tile(Map<String, dynamic> n) {
return Container(
margin: const EdgeInsets.only(bottom: 14),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(18),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.04),
blurRadius: 10,
offset: const Offset(0,6),
)
],
),
child: Row(
children: [

Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: n["color"].withOpacity(.15),
shape: BoxShape.circle,
),
child: Icon(Icons.notifications, color: n["color"]),
),

const SizedBox(width: 14),

Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(
n["title"],
style: TextStyle(
fontWeight: n["unread"]
? FontWeight.bold
: FontWeight.w600,
fontSize: 15,
),
),
Text(
n["time"],
style: const TextStyle(
color: Colors.black45,
fontSize: 12,
),
)
],
),

const SizedBox(height: 6),

Text(
n["desc"],
style: const TextStyle(
color: Colors.black54,
),
),
],
),
),

if (n["unread"])
Container(
margin: const EdgeInsets.only(left: 8),
width: 10,
height: 10,
decoration: const BoxDecoration(
color: Colors.blue,
shape: BoxShape.circle,
),
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
title: const Text("Notifications"),
elevation: 0,
backgroundColor: Colors.white,
foregroundColor: Colors.black,
actions: [
TextButton(
onPressed: () {},
child: const Text("Mark all read"),
)
],
),

body: ListView(
padding: const EdgeInsets.all(20),
children: [

const Text(
"Today",
style: TextStyle(
fontWeight: FontWeight.bold,
fontSize: 18,
),
),

const SizedBox(height: 12),

...notifications.map(tile),

const SizedBox(height: 20),

],
),
);
}
}
