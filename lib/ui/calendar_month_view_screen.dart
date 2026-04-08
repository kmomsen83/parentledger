import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';
import 'day_intelligence_screen.dart';

class CalendarMonthViewScreen extends StatefulWidget {
const CalendarMonthViewScreen({super.key});

@override
State<CalendarMonthViewScreen> createState() =>
_CalendarMonthViewScreenState();
}

class _CalendarMonthViewScreenState
extends State<CalendarMonthViewScreen> {

DateTime currentMonth = DateTime.now();
int? selectedDay;

int totalDays() =>
DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

Color riskColor(int day) {
if (day % 5 == 0) return PLDesign.danger;
if (day % 3 == 0) return PLDesign.warning;
return Colors.transparent;
}

void openDay(int day) {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => DayIntelligenceScreen(
date: DateTime(
currentMonth.year,
currentMonth.month,
day,
),
),
),
);
}

Widget buildDay(int day) {

final risk = riskColor(day);
final isSelected = selectedDay == day;

return GestureDetector(
onTap: () {
setState(() => selectedDay = day);
openDay(day);
},
child: AnimatedContainer(
duration: const Duration(milliseconds: 220),
margin: const EdgeInsets.all(4),
decoration: BoxDecoration(
gradient: isSelected
? LinearGradient(
colors: [
PLDesign.primary.withOpacity(.25),
PLDesign.card
],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
)
: null,
color: isSelected ? null : PLDesign.card,
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: isSelected
? PLDesign.primary
: PLDesign.border,
),
boxShadow: isSelected
? [
BoxShadow(
color:
PLDesign.primary.withOpacity(.25),
blurRadius: 16,
spreadRadius: 1,
)
]
: PLDesign.softShadow,
),
child: Stack(
children: [

/// DAY NUMBER
Positioned(
top: 10,
left: 10,
child: Text(
"$day",
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w700,
fontSize: 14,
),
),
),

/// EXCHANGE ICON
if (day % 4 == 0)
const Positioned(
bottom: 10,
right: 10,
child: Icon(
Icons.swap_horiz_rounded,
size: 16,
color: Colors.white60,
),
),

/// RISK BAR (more premium)
if (risk != Colors.transparent)
Positioned(
bottom: 0,
left: 0,
right: 0,
child: Container(
height: 4,
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [
risk.withOpacity(.4),
risk
],
),
borderRadius:
const BorderRadius.only(
bottomLeft:
Radius.circular(14),
bottomRight:
Radius.circular(14),
),
),
),
),
],
),
),
);
}

@override
Widget build(BuildContext context) {

return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(
title: const Text("Custody Intelligence"),
backgroundColor: PLDesign.surface,
),
body: Column(
children: [

/// ⭐ INTELLIGENCE PANEL (VERY IMPORTANT)
Padding(
padding:
const EdgeInsets.fromLTRB(20, 20, 20, 6),
child: Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [
PLDesign.primary
.withOpacity(.25),
PLDesign.card
],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius: PLDesign.r20,
border:
Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: const Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [

Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text("Compliance",
style: PLDesign.caption),
SizedBox(height: 6),
Text("88%",
style:
PLDesign.statNumber),
],
),

Column(
children: [
Text("Violations",
style: PLDesign.caption),
SizedBox(height: 6),
Text("3",
style:
PLDesign.statNumber),
],
),

Column(
children: [
Text("Exchanges",
style: PLDesign.caption),
SizedBox(height: 6),
Text("12",
style:
PLDesign.statNumber),
],
),
],
),
),
),

const SizedBox(height: 12),

/// ⭐ WEEK LABELS (THIS MAKES IT FEEL REAL SOFTWARE)
const Padding(
padding:
EdgeInsets.symmetric(horizontal: 16),
child: Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
_WeekLabel("S"),
_WeekLabel("M"),
_WeekLabel("T"),
_WeekLabel("W"),
_WeekLabel("T"),
_WeekLabel("F"),
_WeekLabel("S"),
],
),
),

const SizedBox(height: 6),

/// GRID
Expanded(
child: GridView.builder(
padding:
const EdgeInsets.symmetric(horizontal: 12),
itemCount: totalDays(),
gridDelegate:
const SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: 7,
mainAxisSpacing: 4,
crossAxisSpacing: 4,
childAspectRatio: .95,
),
itemBuilder: (_, i) =>
buildDay(i + 1),
),
),
],
),
);
}
}

class _WeekLabel extends StatelessWidget {
final String t;
const _WeekLabel(this.t);

@override
Widget build(BuildContext context) {
return SizedBox(
width: 40,
child: Center(
child: Text(
t,
style: const TextStyle(
color: Colors.white38,
fontWeight: FontWeight.w600,
),
),
),
);
}
}
