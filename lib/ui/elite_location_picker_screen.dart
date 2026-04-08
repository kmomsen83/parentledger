import 'package:flutter/material.dart';
import '../../models/location_result.dart';
import '../../design/design.dart';

class EliteLocationPickerScreen extends StatefulWidget {
const EliteLocationPickerScreen({super.key});

@override
State<EliteLocationPickerScreen> createState() =>
_EliteLocationPickerScreenState();
}

class _EliteLocationPickerScreenState
extends State<EliteLocationPickerScreen> {

final TextEditingController search = TextEditingController();

List<LocationResult> recent = [
LocationResult(
name: "Starbucks — Main Street",
lat: 40.12,
lng: -74.21,
),
LocationResult(
name: "Police Station — Downtown",
lat: 40.18,
lng: -74.25,
),
];

List<LocationResult> recommended = [
LocationResult(
name: "Community Exchange Center",
lat: 40.11,
lng: -74.20,
),
LocationResult(
name: "Public Library Parking",
lat: 40.19,
lng: -74.22,
),
LocationResult(
name: "Target Parking Lot",
lat: 40.21,
lng: -74.24,
),
];

List<LocationResult> results = [];

void runSearch(String q) {
final all = [...recent, ...recommended];

setState(() {
results = all
.where((e) =>
e.name.toLowerCase().contains(q.toLowerCase()))
.toList();
});
}

Widget tile(LocationResult r) {
return GestureDetector(
onTap: () {
Navigator.pop(context, r);
},
child: Container(
margin: const EdgeInsets.only(bottom: 12),
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(20),
gradient: PLDesign.primaryGradient,
),
child: Row(
children: [
const Icon(Icons.location_on, color: Colors.white),
const SizedBox(width: 14),
Expanded(
child: Text(
r.name,
style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.w700,
),
),
),
const Icon(Icons.chevron_right, color: Colors.white)
],
),
),
);
}

Widget section(String title, List<LocationResult> list) {
if (list.isEmpty) return const SizedBox();

return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(title, style: PLDesign.caption),
const SizedBox(height: 12),
...list.map(tile),
const SizedBox(height: 22),
],
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(
title: const Text("Select Location"),
),
body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// SEARCH
TextField(
controller: search,
onChanged: runSearch,
decoration: const InputDecoration(
hintText: "Search exchange location",
prefixIcon: Icon(Icons.search),
),
),

const SizedBox(height: 24),

if (search.text.isNotEmpty)
section("Results", results)
else ...[
section("Recent Locations", recent),
section("Recommended Safe Locations", recommended),
]
],
),
);
}
}
