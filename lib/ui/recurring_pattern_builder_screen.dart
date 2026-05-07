import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/case_context.dart';
import '../../services/recurring_pattern_service.dart';
import '../../services/child_service.dart';
import '../../models/child_model.dart';
import '../../design/design.dart';

class RecurringPatternBuilderScreen extends StatefulWidget {
const RecurringPatternBuilderScreen({super.key});

@override
State<RecurringPatternBuilderScreen> createState() =>
_RecurringPatternBuilderScreenState();
}

class _RecurringPatternBuilderScreenState
extends State<RecurringPatternBuilderScreen> {

String? selectedChildId;
int selectedWeekday = DateTime.monday;
TimeOfDay selectedTime = const TimeOfDay(hour: 17, minute: 0);
String type = "pickup";

bool saving = false;

Future<void> save() async {
final caseId = context.read<CaseContext>().caseId;

if (caseId == null || selectedChildId == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Please select a child")),
);
return;
}

setState(() => saving = true);

final timeString =
"${selectedTime.hour.toString().padLeft(2, "0")}:${selectedTime.minute.toString().padLeft(2, "0")}";

await RecurringPatternService.createPattern(
caseId: caseId,
childId: selectedChildId!,
weekday: selectedWeekday,
time: timeString,
type: type,
);

setState(() => saving = false);

if (!mounted) return;

Navigator.pop(context);
}

@override
Widget build(BuildContext context) {
final caseId = context.watch<CaseContext>().caseId;

if (caseId == null) {
return const Scaffold(
body: Center(child: CircularProgressIndicator()),
);
}

return Scaffold(
backgroundColor: Colors.transparent,
body: PLDesign.screen(
title: "Recurring Exchange",
child: StreamBuilder<List<ChildModel>>(
stream: ChildService.watchChildren(caseId),
builder: (context, snapshot) {

if (!snapshot.hasData) {
return const Center(
child: CircularProgressIndicator(),
);
}

final children = snapshot.data!;

/// 🔥 AUTO SELECT FIRST CHILD
if (children.isNotEmpty && selectedChildId == null) {
selectedChildId = children.first.id;
}

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

/// CHILD
const Text("Child", style: PLDesign.caption),
const SizedBox(height: 8),

DropdownButtonFormField<String>(
initialValue: selectedChildId,
items: children.map((c) {
return DropdownMenuItem<String>(
value: c.id,
child: Text(c.name),
);
}).toList(),
onChanged: (v) {
setState(() => selectedChildId = v);
},
),

const SizedBox(height: 24),

/// WEEKDAY
const Text("Day of Week", style: PLDesign.caption),
const SizedBox(height: 8),

DropdownButtonFormField<int>(
initialValue: selectedWeekday,
items: const [
DropdownMenuItem(value: 1, child: Text("Monday")),
DropdownMenuItem(value: 2, child: Text("Tuesday")),
DropdownMenuItem(value: 3, child: Text("Wednesday")),
DropdownMenuItem(value: 4, child: Text("Thursday")),
DropdownMenuItem(value: 5, child: Text("Friday")),
DropdownMenuItem(value: 6, child: Text("Saturday")),
DropdownMenuItem(value: 7, child: Text("Sunday")),
],
onChanged: (v) {
setState(() => selectedWeekday = v!);
},
),

const SizedBox(height: 24),

/// TIME
const Text("Exchange Time", style: PLDesign.caption),
const SizedBox(height: 8),

GestureDetector(
onTap: () async {
final t = await showTimePicker(
context: context,
initialTime: selectedTime,
);

if (t != null) {
setState(() => selectedTime = t);
}
},
child: Container(
padding: const EdgeInsets.all(16),
decoration: PLDesign.cardDecoration,
child: Text(
selectedTime.format(context),
style: PLDesign.sectionTitle,
),
),
),

const SizedBox(height: 24),

/// TYPE
const Text("Exchange Type", style: PLDesign.caption),
const SizedBox(height: 8),

Row(
children: [

Expanded(
child: ChoiceChip(
label: const Text("Pickup"),
selected: type == "pickup",
onSelected: (_) =>
setState(() => type = "pickup"),
),
),

const SizedBox(width: 12),

Expanded(
child: ChoiceChip(
label: const Text("Dropoff"),
selected: type == "dropoff",
onSelected: (_) =>
setState(() => type = "dropoff"),
),
),
],
),

const SizedBox(height: 36),

/// 🔥 PREMIUM BUTTON
PLDesign.primaryButton(
label: saving
? "Saving..."
: "Create Recurring Exchange",
onTap: saving ? () {} : save,
),
],
);
},
),
),
);
}
}
