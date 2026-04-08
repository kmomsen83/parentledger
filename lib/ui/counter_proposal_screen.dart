import 'package:flutter/material.dart';

class CounterProposalScreen extends StatefulWidget {
const CounterProposalScreen({super.key});

@override
State<CounterProposalScreen> createState() =>
_CounterProposalScreenState();
}

class _CounterProposalScreenState
extends State<CounterProposalScreen> {
double expenseSplit = 50;
TimeOfDay selectedTime = const TimeOfDay(hour: 17, minute: 0);
final TextEditingController noteController =
TextEditingController();

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

Widget sectionCard(Widget child) {
return Container(
margin: const EdgeInsets.only(bottom: 16),
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(22),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.05),
blurRadius: 12)
],
),
child: child,
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff5f6fb),

appBar: AppBar(
title: const Text("Counter Proposal"),
centerTitle: true,
),

body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// ORIGINAL PROPOSAL
sectionCard(
const Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
"Original Proposal",
style: TextStyle(
fontWeight: FontWeight.w800),
),
SizedBox(height: 6),
Text(
"Move custody exchange to 6:00 PM",
style:
TextStyle(color: Colors.black54),
)
],
),
),

/// TIME PICKER
sectionCard(
Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
const Text(
"New Exchange Time",
style: TextStyle(
fontWeight: FontWeight.w700),
),
TextButton(
onPressed: pickTime,
child: Text(
selectedTime.format(context)),
)
],
),
),

/// EXPENSE SPLIT
sectionCard(
Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
"Expense Responsibility",
style: TextStyle(
fontWeight: FontWeight.w700),
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
"${expenseSplit.toInt()}% you • ${(100 - expenseSplit).toInt()}% co-parent",
style: const TextStyle(
color: Colors.black54))
],
),
),

/// NOTE
sectionCard(
Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
"Add Context",
style: TextStyle(
fontWeight: FontWeight.w700),
),
const SizedBox(height: 8),
TextField(
controller: noteController,
maxLines: 3,
decoration: InputDecoration(
hintText:
"Explain reasoning...",
filled: true,
fillColor:
Colors.grey.shade100,
border:
OutlineInputBorder(
borderRadius:
BorderRadius.circular(
14),
borderSide:
BorderSide.none,
),
),
)
],
),
),

/// AI FAIRNESS
sectionCard(
const Row(
children: [
Icon(Icons.psychology,
color: Colors.deepPurple),
SizedBox(width: 10),
Expanded(
child: Text(
"AI Fairness Score: Balanced",
style: TextStyle(
fontWeight:
FontWeight.w700),
),
)
],
),
),

const SizedBox(height: 12),

Row(
children: [

Expanded(
child: ElevatedButton(
onPressed: () {},
child:
const Text("Send Counter"),
),
),

const SizedBox(width: 12),

Expanded(
child: OutlinedButton(
onPressed: () {},
child:
const Text("Withdraw"),
),
),

],
),

const SizedBox(height: 40),

],
),
);
}
}
