import 'package:flutter/material.dart';

class DocumentsLibraryScreen extends StatefulWidget {
const DocumentsLibraryScreen({super.key});

@override
State<DocumentsLibraryScreen> createState() =>
_DocumentsLibraryScreenState();
}

class _DocumentsLibraryScreenState
extends State<DocumentsLibraryScreen> {

final List<Map<String, dynamic>> docs = [
{
"title": "Custody Order 2024",
"child": "Jordan",
"type": "Court Order",
"aiTag": "High Legal Relevance",
"date": "Mar 2"
},
{
"title": "Dental Receipt",
"child": "Ava",
"type": "Expense Evidence",
"aiTag": "Expense Linked",
"date": "Yesterday"
},
{
"title": "Holiday Schedule PDF",
"child": "Jordan",
"type": "Agreement",
"aiTag": "Moderate Relevance",
"date": "Mon"
},
];

Color tagColor(String tag) {
if (tag.contains("High")) return Colors.red;
if (tag.contains("Moderate")) return Colors.orange;
return Colors.green;
}

IconData typeIcon(String type) {
switch (type) {
case "Court Order":
return Icons.gavel;
case "Expense Evidence":
return Icons.receipt_long;
default:
return Icons.description;
}
}

Widget docCard(Map<String, dynamic> d) {
return GestureDetector(
onTap: () {
/// ⭐ Navigate to Document Detail Screen
},
child: Container(
margin: const EdgeInsets.only(bottom: 16),
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(22),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.04),
blurRadius: 14,
offset: const Offset(0, 6),
)
],
),
child: Column(
children: [

/// HEADER
Row(
children: [

CircleAvatar(
radius: 22,
backgroundColor:
Colors.blue.withOpacity(.1),
child: Icon(
typeIcon(d["type"]),
color: Colors.blue,
),
),

const SizedBox(width: 14),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [

Text(
d["title"],
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 17,
),
),

const SizedBox(height: 4),

Text(
"${d["child"]} • ${d["type"]}",
style: const TextStyle(
color: Colors.black54),
),
],
),
),

Text(
d["date"],
style: const TextStyle(
color: Colors.black45,
fontSize: 12),
)
],
),

const SizedBox(height: 14),

/// AI TAG
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: tagColor(d["aiTag"])
.withOpacity(.12),
borderRadius:
BorderRadius.circular(14),
),
child: Row(
children: [
const Icon(Icons.psychology,
size: 18),
const SizedBox(width: 6),
Expanded(
child: Text(
"AI Tag: ${d["aiTag"]}",
style: TextStyle(
color: tagColor(
d["aiTag"]),
fontWeight:
FontWeight.w600),
),
)
],
),
),

const SizedBox(height: 14),

/// ACTIONS
Row(
children: [

Expanded(
child: OutlinedButton(
onPressed: () {},
child:
const Text("Open"),
),
),

const SizedBox(width: 10),

Expanded(
child: ElevatedButton(
onPressed: () {},
child:
const Text("Export"),
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
backgroundColor: const Color(0xfff5f6fb),

appBar: AppBar(
title: const Text("Documents"),
elevation: 0,
backgroundColor: Colors.white,
foregroundColor: Colors.black,
actions: [

IconButton(
icon: const Icon(Icons.search),
onPressed: () {},
),

IconButton(
icon: const Icon(Icons.add),
onPressed: () {
/// ⭐ Upload Document Screen
},
)
],
),

body: ListView.builder(
padding: const EdgeInsets.all(20),
itemCount: docs.length,
itemBuilder: (c, i) =>
docCard(docs[i]),
),
);
}
}
