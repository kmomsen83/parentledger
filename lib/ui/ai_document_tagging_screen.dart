import 'package:flutter/material.dart';

class AiDocumentTaggingScreen extends StatefulWidget {
const AiDocumentTaggingScreen({super.key});

@override
State<AiDocumentTaggingScreen> createState() =>
_AiDocumentTaggingScreenState();
}

class _AiDocumentTaggingScreenState extends State<AiDocumentTaggingScreen> {

List<String> selectedTags = [];

final tags = [
"Custody Violation",
"Late Pickup",
"Medical",
"School",
"Expense",
"Harassment",
"Agreement",
"Safety Concern"
];

@override
Widget build(BuildContext context) {

return Scaffold(
backgroundColor: const Color(0xfff3f5fb),

appBar: AppBar(
elevation: 0,
backgroundColor: Colors.transparent,
leading: IconButton(
icon: const Icon(Icons.arrow_back, color: Color(0xff111827)),
onPressed: () => Navigator.pop(context),
),
centerTitle: true,
title: const Text(
"AI Legal Tagging",
style: TextStyle(
color: Color(0xff111827),
fontWeight: FontWeight.w800,
),
),
),

body: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

/// ⭐ ELITE AI HEADER
Container(
padding: const EdgeInsets.all(22),
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [
Color(0xff4f46e5),
Color(0xff1d4ed8),
],
),
borderRadius: BorderRadius.circular(26),
boxShadow: [
BoxShadow(
color: const Color(0xff4f46e5).withValues(alpha: .35),
blurRadius: 30,
offset: const Offset(0, 18),
)
],
),
child: const Row(
children: [
Icon(Icons.psychology_alt_rounded,
color: Colors.white, size: 36),
SizedBox(width: 16),
Expanded(
child: Text(
"AI detected potential legal relevance.\nReview and confirm evidence tags.",
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w600,
height: 1.4,
),
),
)
],
),
),

const SizedBox(height: 26),

/// ⭐ DOCUMENT PREVIEW PANEL
Container(
height: 240,
width: double.infinity,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(26),
gradient: const LinearGradient(
colors: [
Color(0xfff8fafc),
Color(0xffeef2ff),
],
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: .06),
blurRadius: 30,
offset: const Offset(0, 18),
)
],
),
child: const Center(
child: Icon(
Icons.description_outlined,
size: 70,
color: Color(0xff4f46e5),
),
),
),

const SizedBox(height: 28),

/// ⭐ CONFIDENCE PANEL
Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(20),
),
child: Column(
children: [

const Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
Text(
"AI Confidence Score",
style: TextStyle(
fontWeight: FontWeight.w700,
),
),
Text(
"87%",
style: TextStyle(
color: Color(0xff16a34a),
fontWeight: FontWeight.w800,
),
),
],
),

const SizedBox(height: 12),

ClipRRect(
borderRadius: BorderRadius.circular(10),
child: const LinearProgressIndicator(
value: .87,
minHeight: 10,
backgroundColor: Color(0xffe5e7eb),
color: Color(0xff16a34a),
),
),
],
),
),

const SizedBox(height: 26),

const Text(
"Detected Legal Tags",
style: TextStyle(
fontWeight: FontWeight.w800,
fontSize: 18,
),
),

const SizedBox(height: 14),

Wrap(
spacing: 10,
runSpacing: 10,
children: tags.map((t) {

final selected = selectedTags.contains(t);

return GestureDetector(
onTap: () {
setState(() {
selected
? selectedTags.remove(t)
: selectedTags.add(t);
});
},
child: AnimatedContainer(
duration: const Duration(milliseconds: 220),
padding: const EdgeInsets.symmetric(
horizontal: 18, vertical: 11),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(30),
gradient: selected
? const LinearGradient(
colors: [
Color(0xff3b82f6),
Color(0xff1d4ed8),
],
)
: null,
color: selected
? null
: Colors.white,
boxShadow: selected
? [
BoxShadow(
color: const Color(0xff2563eb)
.withValues(alpha: .35),
blurRadius: 14,
offset: const Offset(0, 6),
)
]
: [],
border: Border.all(
color: selected
? Colors.transparent
: const Color(0xffe5e7eb),
),
),
child: Text(
t,
style: TextStyle(
color: selected
? Colors.white
: const Color(0xff374151),
fontWeight: FontWeight.w600,
),
),
),
);

}).toList(),
),

const SizedBox(height: 30),

/// ⭐ TIMELINE ATTACH
Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(22),
gradient: const LinearGradient(
colors: [
Color(0xffffffff),
Color(0xfff8fafc),
],
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: .05),
blurRadius: 20,
offset: const Offset(0, 12),
)
],
),
child: const Row(
children: [
Icon(Icons.timeline,
color: Color(0xff2563eb)),
SizedBox(width: 14),
Expanded(
child: Text(
"Attach this document to custody timeline",
style: TextStyle(
fontWeight: FontWeight.w700,
),
),
),
Icon(Icons.arrow_forward_ios, size: 16)
],
),
),

const SizedBox(height: 34),

/// ⭐ SAVE BUTTON
GestureDetector(
onTap: () {
Navigator.pop(context);
},
child: Container(
height: 62,
width: double.infinity,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(22),
gradient: const LinearGradient(
colors: [
Color(0xff3b82f6),
Color(0xff1d4ed8),
],
),
boxShadow: [
BoxShadow(
color:
const Color(0xff2563eb).withValues(alpha: .45),
blurRadius: 22,
offset: const Offset(0, 10),
)
],
),
child: const Center(
child: Text(
"Save to Legal Evidence",
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w800,
fontSize: 16,
),
),
),
),
),

const SizedBox(height: 14),

Center(
child: TextButton(
onPressed: () => Navigator.pop(context),
child: const Text(
"Cancel",
style: TextStyle(
color: Colors.black45,
fontWeight: FontWeight.w600,
),
),
),
),
],
),
),
);
}
}
