import 'package:flutter/material.dart';

class CustodyScheduleSetupScreen extends StatefulWidget {
const CustodyScheduleSetupScreen({super.key});

@override
State<CustodyScheduleSetupScreen> createState() =>
_CustodyScheduleSetupScreenState();
}

class _CustodyScheduleSetupScreenState
extends State<CustodyScheduleSetupScreen> {
String scheduleType = "Alternating Weeks";

TimeOfDay exchangeTime =
const TimeOfDay(hour: 17, minute: 0);

final TextEditingController locationController =
TextEditingController();

Future pickTime() async {
final t = await showTimePicker(
context: context,
initialTime: exchangeTime,
);

if (t != null) {
setState(() {
exchangeTime = t;
});
}
}

Widget section(Widget child) {
return Container(
margin: const EdgeInsets.only(bottom: 18),
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

Widget scheduleOption(String title) {
bool active = scheduleType == title;

return GestureDetector(
onTap: () {
setState(() {
scheduleType = title;
});
},
child: AnimatedContainer(
duration: const Duration(milliseconds: 250),
margin: const EdgeInsets.only(bottom: 8),
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: active
? Colors.deepPurple.withOpacity(.08)
: Colors.grey.shade100,
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: active
? Colors.deepPurple
: Colors.transparent,
),
),
child: Row(
children: [
Icon(
Icons.calendar_month,
color: active
? Colors.deepPurple
: Colors.grey,
),
const SizedBox(width: 12),
Text(
title,
style: TextStyle(
fontWeight: FontWeight.w700,
color: active
? Colors.deepPurple
: Colors.black,
),
)
],
),
),
);
}

Widget aiPreviewCard() {
return Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [
Color(0xff4A6CF7),
Color(0xff7A8BFF),
],
),
borderRadius: BorderRadius.circular(22),
),
child: const Row(
children: [
Icon(Icons.psychology, color: Colors.white),
SizedBox(width: 10),
Expanded(
child: Text(
"AI Preview: This schedule will create ~14 custody days monthly with LOW conflict probability.",
style: TextStyle(color: Colors.white),
),
)
],
),
);
}

void saveSchedule() {
/// 🔥 FUTURE REAL LOGIC
/// Save to Firestore
/// Generate recurring calendar events
/// Trigger AI baseline
/// Sync calendar

Navigator.pushNamed(context, "/calendarMonthView");
}

void previewCalendar() {
Navigator.pushNamed(context, "/calendarMonthView");
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff5f6fb),

appBar: AppBar(
title: const Text("Custody Schedule Setup"),
centerTitle: true,
),

body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// SCHEDULE TYPE
section(
Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
"Schedule Pattern",
style:
TextStyle(fontWeight: FontWeight.w800),
),
const SizedBox(height: 12),
scheduleOption("Alternating Weeks"),
scheduleOption("2-2-3 Rotation"),
scheduleOption("Primary Residence"),
],
),
),

/// EXCHANGE TIME
section(
Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
const Text(
"Exchange Time",
style:
TextStyle(fontWeight: FontWeight.w700),
),
TextButton(
onPressed: pickTime,
child:
Text(exchangeTime.format(context)),
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
"Exchange Location",
style:
TextStyle(fontWeight: FontWeight.w700),
),
const SizedBox(height: 8),
TextField(
controller: locationController,
decoration: InputDecoration(
hintText: "School / Neutral Site",
filled: true,
fillColor:
Colors.grey.shade100,
border: OutlineInputBorder(
borderRadius:
BorderRadius.circular(14),
borderSide: BorderSide.none,
),
),
)
],
),
),

/// AI PREVIEW
aiPreviewCard(),

const SizedBox(height: 20),

/// NAV BUTTONS ⭐⭐⭐
Row(
children: [

Expanded(
child: OutlinedButton(
onPressed: previewCalendar,
child:
const Text("Preview in Calendar"),
),
),

const SizedBox(width: 12),

Expanded(
child: ElevatedButton(
onPressed: saveSchedule,
child:
const Text("Save Schedule"),
),
),

],
),

const SizedBox(height: 40)

],
),
);
}
}
