import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/case_context.dart';
import '../../../services/timeline_service.dart';
import '../../../design/design.dart';

class AddTimelineEventScreen extends StatefulWidget {
final String childId;

const AddTimelineEventScreen({
super.key,
required this.childId,
});

@override
State<AddTimelineEventScreen> createState() =>
_AddTimelineEventScreenState();
}

class _AddTimelineEventScreenState
extends State<AddTimelineEventScreen> {

final titleController = TextEditingController();
final notesController = TextEditingController();

String type = "Exchange";
DateTime date = DateTime.now();

bool saving = false;

Future save() async {

final caseId =
context.read<CaseContext>().caseId;

if (caseId == null) return;

if (titleController.text.trim().isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text("Enter event title"),
),
);
return;
}

setState(() => saving = true);

await TimelineService.addEvent(
caseId: caseId,
childId: widget.childId,
type: type,
title: titleController.text.trim(),
notes: notesController.text.trim(),
date: date,
);

setState(() => saving = false);

if (mounted) Navigator.pop(context);
}

Future pickDate() async {

final picked = await showDatePicker(
context: context,
initialDate: date,
firstDate: DateTime(2020),
lastDate: DateTime(2100),
);

if (picked != null) {
setState(() => date = picked);
}
}

@override
void dispose() {
titleController.dispose();
notesController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {

return Scaffold(
body: Stack(
children: [

/// ⭐ SAME PREMIUM BACKGROUND AS ENTRY
Positioned.fill(
child: Image.asset(
"lib/design/premium_entry_screen_background.png",
fit: BoxFit.cover,
),
),

/// ⭐ DARK GLASS OVERLAY
Positioned.fill(
child: Container(
color: Colors.black.withValues(alpha:.55),
),
),

SafeArea(
child: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
child: Column(
children: [

/// ===== HEADER =====
Row(
children: [

IconButton(
icon: const Icon(Icons.arrow_back_ios_new),
onPressed: () => Navigator.pop(context),
),

const Expanded(
child: Center(
child: Text(
"Add Timeline Event",
style: PLDesign.sectionTitle,
),
),
),

const SizedBox(width: 40),
],
),

const SizedBox(height: 28),

/// ===== GLASS CARD =====
Container(
padding: const EdgeInsets.all(22),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha:.06),
borderRadius: PLDesign.r20,
border: Border.all(
color: Colors.white.withValues(alpha:.15),
),
boxShadow: PLDesign.softShadow,
),
child: Column(
children: [

/// TYPE
DropdownButtonFormField<String>(
initialValue: type,
dropdownColor: PLDesign.surface,
style: const TextStyle(color: Colors.white),
decoration: InputDecoration(
filled: true,
fillColor:
Colors.white.withValues(alpha:.04),
border: OutlineInputBorder(
borderRadius:
BorderRadius.circular(14),
borderSide: BorderSide.none,
),
),
items: const [
DropdownMenuItem(
value: "Exchange",
child: Text("Exchange")),
DropdownMenuItem(
value: "Medical",
child: Text("Medical")),
DropdownMenuItem(
value: "School",
child: Text("School")),
DropdownMenuItem(
value: "Note",
child: Text("Note")),
],
onChanged: (v) =>
setState(() => type = v!),
),

const SizedBox(height: 18),

/// TITLE
TextField(
controller: titleController,
style:
const TextStyle(color: Colors.white),
decoration: InputDecoration(
hintText: "Event Title",
hintStyle:
const TextStyle(color: Colors.white38),
filled: true,
fillColor:
Colors.white.withValues(alpha:.04),
border: OutlineInputBorder(
borderRadius:
BorderRadius.circular(14),
borderSide: BorderSide.none,
),
),
),

const SizedBox(height: 18),

/// DATE
GestureDetector(
onTap: pickDate,
child: Container(
padding:
const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha:.04),
borderRadius:
BorderRadius.circular(14),
),
child: Row(
children: [

const Icon(Icons.calendar_today),

const SizedBox(width: 12),

Text(
date
.toString()
.split(" ")
.first,
style: const TextStyle(
color: Colors.white),
),
],
),
),
),

const SizedBox(height: 18),

/// NOTES
TextField(
controller: notesController,
maxLines: 4,
style:
const TextStyle(color: Colors.white),
decoration: InputDecoration(
hintText: "Notes (optional)",
hintStyle:
const TextStyle(color: Colors.white38),
filled: true,
fillColor:
Colors.white.withValues(alpha:.04),
border: OutlineInputBorder(
borderRadius:
BorderRadius.circular(14),
borderSide: BorderSide.none,
),
),
),

const SizedBox(height: 26),

/// SAVE BUTTON
GestureDetector(
onTap: saving ? null : save,
child: Container(
height: 58,
width: double.infinity,
decoration: BoxDecoration(
gradient:
PLDesign.primaryGradient,
borderRadius:
BorderRadius.circular(16),
boxShadow:
PLDesign.glowShadow,
),
child: Center(
child: saving
? const CircularProgressIndicator(
color: Colors.white)
: const Text(
"Save Event",
style:
PLDesign.buttonText,
),
),
),
),
],
),
),
],
),
),
),
],
),
);
}
}
