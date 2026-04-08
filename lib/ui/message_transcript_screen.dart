import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';

class MessageTranscriptScreen extends StatefulWidget {
const MessageTranscriptScreen({super.key});

@override
State<MessageTranscriptScreen> createState() =>
_MessageTranscriptScreenState();
}

class _MessageTranscriptScreenState
extends State<MessageTranscriptScreen> {

String filter = "All";

final List<Map<String, dynamic>> messages = [
{
"sender": "You",
"text": "Can we move exchange to 6PM?",
"time": "Mar 2 • 4:12 PM",
"tone": "neutral"
},
{
"sender": "Co-Parent",
"text": "No. Court order says 5PM.",
"time": "Mar 2 • 4:20 PM",
"tone": "firm"
},
{
"sender": "You",
"text": "Understood. I will be on time.",
"time": "Mar 2 • 4:21 PM",
"tone": "cooperative"
},
];

Color toneColor(String t) {
switch (t) {
case "firm":
return PLDesign.warning;
case "aggressive":
return PLDesign.danger;
case "cooperative":
return PLDesign.success;
default:
return PLDesign.info;
}
}

Widget transcriptBubble(Map m) {

final me = m["sender"] == "You";

return Align(
alignment:
me ? Alignment.centerRight : Alignment.centerLeft,
child: Container(
margin: const EdgeInsets.only(bottom: 14),
padding: const EdgeInsets.all(16),
constraints: const BoxConstraints(maxWidth: 320),
decoration: PLDesign.exportTileDecoration,
child: Column(
crossAxisAlignment:
me
? CrossAxisAlignment.end
: CrossAxisAlignment.start,
children: [

Text(
m["sender"],
style: TextStyle(
fontSize: 11,
color: toneColor(m["tone"]),
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 6),

Text(
m["text"],
style: const TextStyle(
color: Colors.white,
fontSize: 14,
),
),

const SizedBox(height: 8),

Row(
mainAxisSize: MainAxisSize.min,
children: [

Icon(
Icons.psychology,
size: 14,
color: toneColor(m["tone"]),
),

const SizedBox(width: 4),

Text(
m["tone"],
style: TextStyle(
fontSize: 11,
color: toneColor(m["tone"]),
),
),

const SizedBox(width: 10),

Text(
m["time"],
style: const TextStyle(
fontSize: 10,
color: Colors.white54,
),
),
],
)
],
),
),
);
}

Widget filterChip(String name) {

final active = filter == name;

return GestureDetector(
onTap: () => setState(() => filter = name),
child: Container(
margin: const EdgeInsets.only(right: 10),
padding: const EdgeInsets.symmetric(
horizontal: 16,
vertical: 8,
),
decoration: BoxDecoration(
gradient:
active ? PLDesign.primaryGradient : null,
color: active ? null : PLDesign.card,
borderRadius: BorderRadius.circular(30),
border: Border.all(color: PLDesign.border),
),
child: Text(
name,
style: TextStyle(
color:
active
? Colors.white
: PLDesign.textMuted,
fontWeight: FontWeight.w600,
),
),
),
);
}

Widget aiSummary() {
return Container(
padding: const EdgeInsets.all(22),
decoration: PLDesign.legalCard,
child: const Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [

Row(
children: [
Icon(Icons.psychology,
color: PLDesign.ai),
SizedBox(width: 8),
Text(
"AI Communication Summary",
style: PLDesign.sectionTitle,
),
],
),

SizedBox(height: 8),

Text(
"Tone mostly cooperative. No harassment detected. "
"1 firm directive referencing court order.",
style: PLDesign.legalBody,
)
],
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: PLDesign.background,
body: PLDesign.screen(
title: "Message Transcript",
actions: [

IconButton(
icon: const Icon(Icons.download,
color: Colors.white),
onPressed: () {
/// ⭐ export transcript
},
)

],
child: Column(
children: [

aiSummary(),

const SizedBox(height: 18),

SizedBox(
height: 46,
child: ListView(
scrollDirection: Axis.horizontal,
children: [

filterChip("All"),
filterChip("Firm"),
filterChip("Aggressive"),
filterChip("Cooperative"),

],
),
),

const SizedBox(height: 18),

...messages.map(transcriptBubble),

const SizedBox(height: 40),

],
),
),
);
}
}
