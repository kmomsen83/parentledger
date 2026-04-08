import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/design.dart';
import '../../services/location_service.dart';

class ExchangeCheckinScreen extends StatefulWidget {
final String exchangeId;
final DateTime scheduledTime;

final double exchangeLat;
final double exchangeLng;
final String locationName;

const ExchangeCheckinScreen({
super.key,
required this.exchangeId,
required this.scheduledTime,
required this.exchangeLat,
required this.exchangeLng,
required this.locationName,
});

@override
State<ExchangeCheckinScreen> createState() =>
_ExchangeCheckinScreenState();
}

class _ExchangeCheckinScreenState
extends State<ExchangeCheckinScreen> {

Position? pos;

String? arrivalStatus;
String arrivalLabel = "";

int minutesDelta = 0;
double distance = 0;

bool loading = false;
bool capturedOnce = false;
bool confirming = false;

XFile? photo;

@override
void initState() {
super.initState();

Future.delayed(const Duration(milliseconds: 500), capture);
checkAutoMissed();
}

/// ================================
/// 📍 CAPTURE LOCATION
/// ================================
Future<void> capture() async {
if (loading) return;

setState(() => loading = true);

final p = await LocationService.getExchangeLocation();

if (!mounted) return;

if (p == null) {
setState(() => loading = false);
return;
}

final meters = Geolocator.distanceBetween(
p.latitude,
p.longitude,
widget.exchangeLat,
widget.exchangeLng,
);

final now = DateTime.now();
final diff =
now.difference(widget.scheduledTime).inMinutes;

String status;
String label;

if (diff < -120) {
status = "too_early";
label = "Too early";
} else if (meters > 250) {
status = "wrong_location";
label = "Wrong location";
} else if (diff < -10) {
status = "early";
label = "Early";
} else if (diff <= 5) {
status = "on_time";
label = "On time";
} else if (diff <= 20) {
status = "late";
label = "Late";
} else {
status = "very_late";
label = "Very late";
}

setState(() {
pos = p;
distance = meters;
minutesDelta = diff;
arrivalStatus = status;
arrivalLabel = label;
loading = false;
capturedOnce = true;
});
}

/// ================================
/// 📸 PHOTO
/// ================================
Future<void> capturePhoto() async {
final img =
await ImagePicker().pickImage(source: ImageSource.camera);

if (!mounted) return;

if (img != null) {
setState(() => photo = img);
}
}

/// ================================
/// 🔐 HASH
/// ================================
String generateHash(Map<String, dynamic> data) {
return sha256
.convert(utf8.encode(jsonEncode(data)))
.toString();
}

/// ================================
/// ⚠️ AUTO MISSED
/// ================================
Future<void> checkAutoMissed() async {
final now = DateTime.now();

if (now.isBefore(
widget.scheduledTime.add(const Duration(minutes: 30)))) {
  return;
}

final db = FirebaseFirestore.instance;

final existing = await db
.collection("riskEvents")
.where("linkedExchangeId", isEqualTo: widget.exchangeId)
.limit(1)
.get();

if (existing.docs.isNotEmpty) return;

await db.collection("riskEvents").add({
"type": "missed_exchange",
"severity": 2,
"linkedExchangeId": widget.exchangeId,
"timestamp": FieldValue.serverTimestamp(),
});
}

/// ================================
/// 🔥 CONFIRM
/// ================================
Future<void> confirm(String type) async {
if (pos == null || confirming) return;

setState(() => confirming = true);

final db = FirebaseFirestore.instance;
final uid = FirebaseAuth.instance.currentUser!.uid;
final now = DateTime.now();

String riskType = "compliance";
int severity = 1;

switch (arrivalStatus) {
case "on_time":
case "early":
riskType = "compliance";
break;
case "late":
riskType = "late";
break;
case "very_late":
riskType = "late";
severity = 2;
break;
case "wrong_location":
riskType = "missed_exchange";
severity = 2;
break;
default:
riskType = "neutral";
}

final baseData = {
"type": type,
"arrivalStatus": arrivalStatus,
"minutesDelta": minutesDelta,
"distanceMeters": distance,
"lat": pos!.latitude,
"lng": pos!.longitude,
"userId": uid,
"exchangeId": widget.exchangeId,
"time": now.toIso8601String(),
};

final hash = generateHash(baseData);

final eventRef = await db
.collection("exchanges")
.doc(widget.exchangeId)
.collection("events")
.add({
...baseData,
"timestamp": Timestamp.now(),
"serverTime": FieldValue.serverTimestamp(),
"accuracy": pos!.accuracy,
"speed": pos!.speed,
"heading": pos!.heading,
"photoPath": photo?.path,
"hash": hash,
"isLocked": true,
});

await db.collection("riskEvents").add({
"userId": uid,
"type": riskType,
"severity": severity,
"linkedExchangeId": widget.exchangeId,
"linkedEventId": eventRef.id,
"timestamp": FieldValue.serverTimestamp(),
"eventHash": hash,
});

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text("$type recorded")),
);

Navigator.pop(context);
}

Color statusColor() {
switch (arrivalStatus) {
case "on_time":
return Colors.green;
case "late":
return Colors.orange;
case "very_late":
return Colors.red;
case "wrong_location":
return Colors.purple;
default:
return Colors.grey;
}
}

/// ================================
/// UI
/// ================================
@override
Widget build(BuildContext context) {
final scheduled =
DateFormat.jm().format(widget.scheduledTime);

return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(
title: const Text("Exchange Check-In"),
),
body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// HEADER
Container(
padding: const EdgeInsets.all(24),
decoration: PLDesign.gradientCard,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(widget.locationName,
style: PLDesign.heroTitle),
Text("Scheduled • $scheduled",
style: PLDesign.caption),
],
),
),

const SizedBox(height: 20),

/// MAP
Container(
height: 220,
decoration: PLDesign.cardDecoration,
child: pos == null
? const Center(child: Text("Locating..."))
: GoogleMap(
initialCameraPosition: CameraPosition(
target: LatLng(widget.exchangeLat, widget.exchangeLng),
zoom: 15,
),
markers: {
Marker(
markerId: const MarkerId("you"),
position: LatLng(pos!.latitude, pos!.longitude),
),
Marker(
markerId: const MarkerId("exchange"),
position: LatLng(widget.exchangeLat, widget.exchangeLng),
),
},
),
),

const SizedBox(height: 20),

/// STATUS CARD
if (arrivalStatus != null)
Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: statusColor().withOpacity(.1),
borderRadius: BorderRadius.circular(16),
),
child: Row(
children: [
Icon(Icons.analytics, color: statusColor()),
const SizedBox(width: 12),
Expanded(
child: Text(
"$arrivalLabel • ${distance.toStringAsFixed(0)}m • $minutesDelta min",
style: PLDesign.sectionTitle,
),
),
],
),
),

const SizedBox(height: 20),

ElevatedButton(
onPressed: loading ? null : capture,
child: loading
? const CircularProgressIndicator()
: const Text("Re-Capture"),
),

const SizedBox(height: 12),

ElevatedButton(
onPressed: capturePhoto,
child: Text(photo == null
? "Add Photo Proof"
: "Photo Added ✓"),
),

const SizedBox(height: 20),

Row(
children: [
Expanded(
child: ElevatedButton(
onPressed: confirming
? null
: () => confirm("dropoff"),
child: const Text("Drop-Off"),
),
),
const SizedBox(width: 12),
Expanded(
child: ElevatedButton(
onPressed: confirming
? null
: () => confirm("pickup"),
child: const Text("Pick-Up"),
),
),
],
),
],
),
);
}
}
