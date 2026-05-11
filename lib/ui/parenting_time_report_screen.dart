import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:parentledger/design/design.dart';
import '../services/court_pdf_service.dart';
import 'pdf_preview_screen.dart';
import 'recent_activity_timeline_screen.dart';

class ParentingTimeReportScreen extends StatefulWidget {
const ParentingTimeReportScreen({super.key});

@override
State<ParentingTimeReportScreen> createState() =>
_ParentingTimeReportScreenState();
}

class _ParentingTimeReportScreenState
extends State<ParentingTimeReportScreen> {

bool loading = true;
bool exporting = false;

int overnights = 0;
int exchanges = 0;
int missed = 0;

double yourTime = 0.5;
double coparentTime = 0.5;

int compliance = 100;
int riskScore = 0;
int stabilityScore = 100;

List<QueryDocumentSnapshot> events = [];
List<String> alerts = [];

@override
void initState() {
super.initState();
loadData();
}

/// ================================
/// 🔥 LOAD REAL DATA (SAFE)
/// ================================
Future<void> loadData() async {
try {
final user = FirebaseAuth.instance.currentUser;
if (user == null) return;

final uid = user.uid;
final db = FirebaseFirestore.instance;

final snap = await db
.collection("riskEvents")
.where("userId", isEqualTo: uid)
.get();

/// RESET COUNTERS (IMPORTANT)
exchanges = 0;
overnights = 0;
missed = 0;
riskScore = 0;

events = snap.docs;

int totalDays = 0;
int userDays = 0;
int risk = 0;

for (var doc in snap.docs) {
final Map<String, dynamic> d = Map<String, dynamic>.from(doc.data());

final type = d["type"] ?? "";
final rawSeverity = d["severity"];
final int severity = rawSeverity is int ? rawSeverity : 1;

if (type == "exchange") exchanges++;

if (type == "overnight") {
totalDays++;
if (d["owner"] == uid) userDays++;
}

if (type == "missed_exchange") {
missed++;
risk += 15 * severity;
}

if (type == "late") {
risk += 8 * severity;
}

if (type == "message_conflict") {
risk += 5 * severity;
}

if (type == "compliance") {
risk -= 10 * severity;
}
}

overnights = totalDays;

if (totalDays > 0) {
yourTime = userDays / totalDays;
coparentTime = 1 - yourTime;
} else {
yourTime = 0.5;
coparentTime = 0.5;
}

compliance = calculateCompliance();
riskScore = risk.clamp(0, 100);

/// BALANCED FINAL SCORE
stabilityScore =
(compliance - (riskScore * 0.7)).clamp(0, 100).toInt();

alerts = generateAlerts();

if (mounted) setState(() => loading = false);

} catch (e) {
if (mounted) {
setState(() => loading = false);
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Failed to load data")),
);
}
}
}

/// ================================
/// 🧠 COMPLIANCE LOGIC
/// ================================
int calculateCompliance() {
int score = 100;

score -= missed * 10;

if ((yourTime - 0.5).abs() > 0.15) {
score -= 10;
}

return score.clamp(0, 100);
}

/// ================================
/// ⚠️ ALERT ENGINE
/// ================================
List<String> generateAlerts() {
List<String> list = [];

if (missed > 0) {
list.add("Missed exchanges detected ($missed)");
}

if (riskScore > 60) {
list.add('Elevated case compliance indicators detected');
}

if ((yourTime - 0.5).abs() > 0.15) {
list.add("Parenting time imbalance detected");
}

if (list.isEmpty) {
list.add("No issues detected");
}

return list;
}

/// ================================
/// 🧠 LEGALLY SAFE NARRATIVE
/// ================================
String buildNarrative() {
if (stabilityScore > 85) {
return "Recorded data indicates consistent co-parenting behavior with minimal disruption.";
}

if (stabilityScore > 65) {
return "Recorded events indicate moderate variability in adherence to schedule and communication.";
}

return "Recorded data indicates repeated inconsistencies. Continued documentation is recommended.";
}

/// ================================
/// 📄 EXPORT REPORT (SAFE UX)
/// ================================
Future<void> exportReport() async {
if (exporting) return;

setState(() => exporting = true);

try {
final eventsData = events.map((e) {
final d = e.data() as Map<String, dynamic>;
return {
"type": d["type"],
"severity": d["severity"] ?? 1,
};
}).toList();

final bytes = await CourtPdfService.buildCourtSummaryPdfBytes(
complianceScore: compliance,
exchanges: exchanges,
violations: missed,
proposals: 0,
messages: 0,
expenses: 0,
documents: 0,
events: eventsData,
narrative: buildNarrative(),
);

final file = await CourtPdfService.writePdfBytesToTempFile(bytes);
await CourtPdfService.rememberLastGeneratedCourtSummaryPath(file.path);

if (!mounted) return;

await Navigator.of(context).push<void>(
MaterialPageRoute<void>(
builder: (_) => PDFPreviewScreen(
filePath: file.path,
title: 'Court Summary',
),
),
);

if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Court report ready")),
);
}

} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Export failed")),
);
}

if (mounted) setState(() => exporting = false);
}

/// ================================
/// UI COMPONENTS
/// ================================
Widget metricCard(String title, String value, Color color) {
return Expanded(
child: Container(
padding: const EdgeInsets.all(16),
decoration: PLDesign.elevatedCard,
child: Column(
children: [
Text(value,
style: TextStyle(
fontSize: 26,
fontWeight: FontWeight.w900,
color: color)),
const SizedBox(height: 6),
Text(title, style: PLDesign.caption),
],
),
),
);
}

Widget distributionBar(String label, double value, Color color) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(label, style: PLDesign.sectionTitle),
const SizedBox(height: 8),
ClipRRect(
borderRadius: BorderRadius.circular(12),
child: LinearProgressIndicator(
value: value,
minHeight: 14,
backgroundColor: PLDesign.border,
valueColor: AlwaysStoppedAnimation(color),
),
),
const SizedBox(height: 18),
],
);
}

Widget alertTile(String text) {
return Container(
margin: const EdgeInsets.only(bottom: 12),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: PLDesign.warning.withValues(alpha:.08),
borderRadius: BorderRadius.circular(16),
border: Border.all(color: PLDesign.warning.withValues(alpha:.3)),
),
child: Row(
children: [
const Icon(Icons.warning_amber_rounded,
color: PLDesign.warning),
const SizedBox(width: 12),
Expanded(child: Text(text, style: PLDesign.body)),
],
),
);
}

/// ================================
/// BUILD
/// ================================
@override
Widget build(BuildContext context) {
if (loading) {
return const Scaffold(
body: Center(child: CircularProgressIndicator()),
);
}

return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(title: const Text("Parenting Time Report")),
body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// HEADER
Container(
padding: const EdgeInsets.all(24),
decoration: PLDesign.gradientCard,
child: Column(
children: [
const Text("Co-Parent Stability Score",
style: TextStyle(color: Colors.white70)),
const SizedBox(height: 6),
Text("$stabilityScore",
style: const TextStyle(
fontSize: 40,
fontWeight: FontWeight.w900,
color: Colors.white)),
const SizedBox(height: 8),
Text("Compliance: $compliance | Risk: $riskScore",
style: const TextStyle(color: Colors.white70)),
],
),
),

const SizedBox(height: 22),

Row(
children: [
metricCard("Overnights", "$overnights", PLDesign.primary),
const SizedBox(width: 12),
metricCard("Exchanges", "$exchanges", PLDesign.success),
const SizedBox(width: 12),
metricCard("Missed", "$missed", PLDesign.danger),
],
),

const SizedBox(height: 26),

distributionBar("Your Time", yourTime, PLDesign.primary),
distributionBar("Co-Parent", coparentTime, PLDesign.warning),

const SizedBox(height: 26),

...alerts.map(alertTile),

const SizedBox(height: 26),

Container(
padding: const EdgeInsets.all(20),
decoration: PLDesign.aiSurface,
child: Text(buildNarrative(), style: PLDesign.legalBody),
),

const SizedBox(height: 30),

Row(
children: [
Expanded(
child: PLDesign.primaryButton(
label: "Open Timeline",
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
const RecentActivityTimelineScreen(),
),
);
},
),
),
const SizedBox(width: 12),
Expanded(
child: OutlinedButton(
onPressed: exporting ? null : exportReport,
child: exporting
? const SizedBox(
height: 18,
width: 18,
child: CircularProgressIndicator(strokeWidth: 2),
)
: const Text("Export Report"),
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
