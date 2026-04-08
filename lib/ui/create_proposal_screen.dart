import 'package:flutter/material.dart';

class CreateProposalScreen extends StatefulWidget {
const CreateProposalScreen({super.key});

@override
State<CreateProposalScreen> createState() =>
_CreateProposalScreenState();
}

class _CreateProposalScreenState
extends State<CreateProposalScreen> {
DateTime selectedDate = DateTime.now();
TimeOfDay selectedTime =
const TimeOfDay(hour: 17, minute: 0);

double expenseSplit = 50;

String proposalType = "Schedule";

final TextEditingController location =
TextEditingController();

final TextEditingController note =
TextEditingController();

Future pickDate() async {
final d = await showDatePicker(
context: context,
initialDate: selectedDate,
firstDate: DateTime.now()
.subtract(const Duration(days: 365)),
lastDate:
DateTime.now().add(const Duration(days: 365)),
);

if (d != null) {
setState(() {
selectedDate = d;
});
}
}

Future pickTime() async {
final t = await showTimePicker(
context: context,
initialTime: selectedTime);

if (t != null) {
setState(() {
selectedTime = t;
});
}
}

Widget section(Widget child) {
return Container(
margin: const EdgeInsets.only(bottom: 16),
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(22),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.05),
blurRadius: 12,
)
],
),
child: child,
);
}

Widget typeChip(String label) {
bool active = proposalType == label;

return GestureDetector(
onTap: () {
setState(() {
proposalType = label;
});
},
child: Container(
padding: const EdgeInsets.symmetric(
horizontal: 14, vertical: 8),
decoration: BoxDecoration(
color: active
? Colors.deepPurple
: Colors.grey.shade200,
borderRadius: BorderRadius.circular(20),
),
child: Text(
label,
style: TextStyle(
color: active ? Colors.white : Colors.black,
fontWeight: FontWeight.w600,
),
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff5f6fb),

appBar: AppBar(
title: const Text("Create Proposal"),
centerTitle: true,
),

body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// TYPE SELECT
section(
Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
"Proposal Type",
style:
TextStyle(fontWeight: FontWeight.w800),
),
const SizedBox(height: 10),
Row(
children: [
typeChip("Schedule"),
const SizedBox(width: 8),
typeChip("Expense"),
const SizedBox(width: 8),
typeChip("Location"),
],
)
],
),
),

/// DATE TIME
section(
Column(
children: [
Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
const Text("Date",
style: TextStyle(
fontWeight: FontWeight.w700)),
TextButton(
onPressed: pickDate,
child: Text(
"${selectedDate.month}/${selectedDate.day}/${selectedDate.year}"),
)
],
),
Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
const Text("Time",
style: TextStyle(
fontWeight: FontWeight.w700)),
TextButton(
onPressed: pickTime,
child:
Text(selectedTime.format(context)),
)
],
)
],
),
),

/// LOCATION
section(
Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
"Location",
style:
TextStyle(fontWeight: FontWeight.w700),
),
const SizedBox(height: 8),
TextField(
controller: location,
decoration: InputDecoration(
hintText: "Exchange location",
filled: true,
fillColor:
Colors.grey.shade100,
border: OutlineInputBorder(
borderRadius:
BorderRadius.circular(14),
borderSide:
BorderSide.none),
),
)
],
),
),

/// EXPENSE SPLIT
section(
Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
"Expense Responsibility",
style:
TextStyle(fontWeight: FontWeight.w700),
),
Slider(
value: expenseSplit,
min: 0,
max: 100,
divisions: 20,
label:
"${expenseSplit.toInt()}%",
onChanged: (v) {
setState(() {
expenseSplit = v;
});
},
),
Text(
"${expenseSplit.toInt()}% you • ${(100 - expenseSplit).toInt()}% co-parent")
],
),
),

/// NOTE
section(
Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
"Reasoning",
style:
TextStyle(fontWeight: FontWeight.w700),
),
const SizedBox(height: 8),
TextField(
controller: note,
maxLines: 3,
decoration: InputDecoration(
hintText: "Explain proposal...",
filled: true,
fillColor:
Colors.grey.shade100,
border: OutlineInputBorder(
borderRadius:
BorderRadius.circular(14),
borderSide:
BorderSide.none),
),
)
],
),
),

/// AI PREVIEW
section(
const Row(
children: [
Icon(Icons.psychology,
color: Colors.deepPurple),
SizedBox(width: 10),
Expanded(
child: Text(
"AI Fairness Score: Strong • Acceptance Probability: 72%",
style: TextStyle(
fontWeight: FontWeight.w700),
),
)
],
),
),

const SizedBox(height: 10),

ElevatedButton(
onPressed: () {},
child: const Text("Send Proposal"),
),

const SizedBox(height: 40)

],
),
);
}
}
