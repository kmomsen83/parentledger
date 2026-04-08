import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_places_flutter/google_places_flutter.dart';

import '../../design/design.dart';
import '../../providers/case_context.dart';

class CreateExchangeScreen extends StatefulWidget {
const CreateExchangeScreen({super.key});

@override
State<CreateExchangeScreen> createState() =>
_CreateExchangeScreenState();
}

class _CreateExchangeScreenState
extends State<CreateExchangeScreen> {

/// ================================
/// STATE
/// ================================
String type = "pickup";

DateTime? selectedDate;
TimeOfDay? selectedTime;

String locationName = "";
double? lat;
double? lng;

/// CHILDREN
String? selectedChildId;
List<Map<String, dynamic>> children = [];
bool loadingChildren = true;

bool saving = false;

final TextEditingController locationController =
TextEditingController();

/// ================================
/// INIT
/// ================================
@override
void initState() {
super.initState();
loadChildren();
}

Future<void> loadChildren() async {
final caseId = context.read<CaseContext>().caseId;

final snap = await FirebaseFirestore.instance
.collection("cases")
.doc(caseId)
.collection("children")
.get();

children = snap.docs.map((d) => {
"id": d.id,
"name": d["name"] ?? "Child",
}).toList();

/// AUTO SELECT
if (children.length == 1) {
selectedChildId = children.first["id"];
}

setState(() => loadingChildren = false);
}

/// ================================
/// DATE PICKER
/// ================================
Future<void> pickDate() async {
final now = DateTime.now();

final d = await showDatePicker(
context: context,
initialDate: now,
firstDate: now.subtract(const Duration(days: 1)),
lastDate: now.add(const Duration(days: 365)),
);

if (d != null) {
setState(() => selectedDate = d);
}
}

/// ================================
/// TIME PICKER
/// ================================
Future<void> pickTime() async {
final t = await showTimePicker(
context: context,
initialTime: TimeOfDay.now(),
);

if (t != null) {
setState(() => selectedTime = t);
}
}

/// ================================
/// SAVE
/// ================================
Future<void> createExchange() async {
if (saving) return;

final caseId = context.read<CaseContext>().caseId;

if (caseId == null ||
selectedDate == null ||
selectedTime == null ||
locationName.isEmpty ||
lat == null ||
lng == null ||
selectedChildId == null) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Complete all fields")),
);
return;
}

setState(() => saving = true);

final scheduled = DateTime(
selectedDate!.year,
selectedDate!.month,
selectedDate!.day,
selectedTime!.hour,
selectedTime!.minute,
);

await FirebaseFirestore.instance
.collection("cases")
.doc(caseId)
.collection("exchanges")
.add({
"type": type,
"status": "scheduled",
"childId": selectedChildId,

"scheduledTime": Timestamp.fromDate(scheduled),

"locationName": locationName,
"lat": lat,
"lng": lng,

/// AUDIT
"createdAt": FieldValue.serverTimestamp(),
});

if (!mounted) return;

Navigator.pop(context);
}

/// ================================
/// BUILD
/// ================================
@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(
title: const Text("Schedule Exchange"),
),
body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// TYPE
const Text("Exchange Type",
style: PLDesign.sectionTitle),
const SizedBox(height: 12),

Row(
children: [
_typeButton("pickup"),
const SizedBox(width: 12),
_typeButton("dropoff"),
],
),

const SizedBox(height: 24),

/// CHILD SELECT
const Text("Child",
style: PLDesign.sectionTitle),
const SizedBox(height: 10),

loadingChildren
? const CircularProgressIndicator()
: children.length == 1
? _inputBox(children.first["name"])
: DropdownButtonFormField<String>(
initialValue: selectedChildId,
items: children.map<DropdownMenuItem<String>>((c) {
return DropdownMenuItem<String>(
value: c["id"].toString(),
child: Text(c["name"] ?? "Child"),
);
}).toList(),
onChanged: (v) {
setState(() => selectedChildId = v);
},
decoration: const InputDecoration(
hintText: "Select child",
),
),

const SizedBox(height: 24),

/// DATE
_field(
label: "Date",
value: selectedDate == null
? "Select date"
: DateFormat.yMMMd().format(selectedDate!),
onTap: pickDate,
),

const SizedBox(height: 12),

/// TIME
_field(
label: "Time",
value: selectedTime == null
? "Select time"
: selectedTime!.format(context),
onTap: pickTime,
),

const SizedBox(height: 24),

/// LOCATION (GOOGLE PLACES)
const Text("Location",
style: PLDesign.sectionTitle),
const SizedBox(height: 10),

GooglePlaceAutoCompleteTextField(
textEditingController: locationController,
googleAPIKey: "YOUR_API_KEY_HERE",
inputDecoration: const InputDecoration(
hintText: "Search address",
),
debounceTime: 600,
isLatLngRequired: true,
getPlaceDetailWithLatLng: (prediction) {
lat = double.tryParse(prediction.lat ?? "");
lng = double.tryParse(prediction.lng ?? "");
},
itemClick: (prediction) {
locationController.text =
prediction.description ?? "";
locationName = prediction.description ?? "";
lat = double.tryParse(prediction.lat ?? "");
lng = double.tryParse(prediction.lng ?? "");

setState(() {});
},
),

const SizedBox(height: 30),

/// SUBMIT
ElevatedButton(
onPressed: saving ? null : createExchange,
child: saving
? const CircularProgressIndicator()
: const Text("Create Exchange"),
),
],
),
);
}

/// ================================
/// UI HELPERS
/// ================================
Widget _typeButton(String t) {
final active = type == t;

return Expanded(
child: GestureDetector(
onTap: () => setState(() => type = t),
child: Container(
padding: const EdgeInsets.symmetric(vertical: 16),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: active
? PLDesign.primary
: PLDesign.border,
),
color: active
? PLDesign.primary.withOpacity(.15)
: PLDesign.card,
),
child: Center(
child: Text(
t.toUpperCase(),
style: TextStyle(
color: active
? PLDesign.primary
: Colors.white,
fontWeight: FontWeight.w700,
),
),
),
),
),
);
}

Widget _field({
required String label,
required String value,
required VoidCallback onTap,
}) {
return GestureDetector(
onTap: onTap,
child: Container(
padding:
const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
decoration: BoxDecoration(
  color: PLDesign.card,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: PLDesign.border),
),
child: Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
Text(label, style: PLDesign.caption),
Text(value, style: PLDesign.body),
],
),
),
);
}

Widget _inputBox(String text) {
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
  color: PLDesign.card,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: PLDesign.border),
),
child: Text(text, style: PLDesign.body),
);
}
}
