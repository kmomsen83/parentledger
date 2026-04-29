import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'package:parentledger/design/design.dart';
import 'package:parentledger/providers/case_context.dart';
import 'package:parentledger/ui/widgets/parent_upgrade_prompt.dart';

class CustodyRiskScreen extends StatefulWidget {
const CustodyRiskScreen({super.key});

@override
State<CustodyRiskScreen> createState() => _CustodyRiskScreenState();
}

class _CustodyRiskScreenState extends State<CustodyRiskScreen> {
int score = 20;
List<QueryDocumentSnapshot> events = [];

@override
void initState() {
super.initState();
loadData();
}

/// ================================
/// 🔥 LOAD FIRESTORE DATA
/// ================================
Future<void> loadData() async {
final uid = FirebaseAuth.instance.currentUser!.uid;

final snap = await FirebaseFirestore.instance
.collection("riskEvents")
.where("userId", isEqualTo: uid)
.orderBy("timestamp")
.limit(30)
.get();

events = snap.docs;
score = calculateScore(events);

if (mounted) setState(() {});
}

/// ================================
/// 🧠 SCORE (SAFE NAMING)
/// ================================
int calculateScore(List<QueryDocumentSnapshot> docs) {
int s = 20;

for (var doc in docs) {
final data = doc.data() as Map<String, dynamic>;

final type = data["type"] ?? "";
final severity = (data["severity"] ?? 1) as int;

switch (type) {
case "missed_exchange":
s += 15 * severity;
break;
case "late":
s += 6 * severity;
break;
case "message_conflict":
s += 4 * severity;
break;
case "compliance":
s -= 5 * severity;
break;
}
}

return s.clamp(0, 100).toInt();
}

/// ================================
/// 📈 GRAPH
/// ================================
List<FlSpot> buildSpots() {
int running = 20;

return events.asMap().entries.map((entry) {
final data = entry.value.data() as Map<String, dynamic>;
final type = data["type"];

switch (type) {
case "missed_exchange":
running += 15;
break;
case "late":
running += 6;
break;
case "message_conflict":
running += 4;
break;
case "compliance":
running -= 5;
break;
}

running = running.clamp(0, 100);

return FlSpot(entry.key.toDouble(), running.toDouble());
}).toList();
}

/// ================================
/// ⚠️ EVENTS (DRIVERS)
/// ================================
List<Map<String, dynamic>> getRecentEvents() {
return events.reversed.take(5).map((doc) {
final d = doc.data() as Map<String, dynamic>;

return {
"type": d["type"] ?? "",
"severity": d["severity"] ?? 1,
};
}).toList();
}

/// ================================
/// 🎯 RECOMMENDATIONS
/// ================================
List<String> getRecommendations() {
final hasMissed =
events.any((e) => (e.data() as Map)["type"] == "missed_exchange");

final hasLate =
events.any((e) => (e.data() as Map)["type"] == "late");

final hasConflict =
events.any((e) => (e.data() as Map)["type"] == "message_conflict");

List<String> list = [];

if (hasMissed) {
list.add("Document missed exchanges immediately");
}

if (hasLate) {
list.add("Arrive early for scheduled exchanges");
}

if (hasConflict) {
list.add("Keep communication brief and factual");
}

list.add("Maintain consistent documentation of events");

return list;
}

/// ================================
/// 📊 LABELS
/// ================================
String label() {
if (score < 30) return "Stable Patterns";
if (score < 60) return "Emerging Concerns";
return "Elevated Conflict Pattern";
}

Color color() {
if (score < 30) return Colors.greenAccent;
if (score < 60) return Colors.orangeAccent;
return Colors.redAccent;
}

/// ================================
/// 📄 COURT EXPORT
/// ================================
Future<void> generateSummary() async {
final uid = FirebaseAuth.instance.currentUser!.uid;
final caseId = context.read<CaseContext>().caseId;
if (caseId == null) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Case context missing")),
);
return;
}

final summary = events.map((e) {
final d = e.data() as Map<String, dynamic>;
return "- ${d['type']} (Severity ${d['severity']})";
}).join("\n");

final ref = FirebaseFirestore.instance
.collection("cases")
.doc(caseId)
.collection("legalSummaries")
.doc();

await ref.set(
{
"summaryId": ref.id,
"caseId": caseId,
"createdBy": uid,
"summaryText": summary,
"createdAt": FieldValue.serverTimestamp(),
},
SetOptions(merge: true),
);

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Court summary generated")),
);
}

/// ================================
/// 🧱 BUILD
/// ================================
@override
Widget build(BuildContext context) {
final session = context.watch<CaseContext>();
if (!session.isAttorney && !session.unlockedParentPremiumFeatures) {
return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(title: Text(context.tTone('custodyRisk'))),
body: Padding(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
const SizedBox(height: 24),
Text(
'Advanced insights',
style: PLDesign.heroTitle.copyWith(fontSize: 26),
),
const SizedBox(height: 12),
Text(
'Full history analytics and pattern views are part of ParentLedger Pro.',
style: PLDesign.body.copyWith(
color: PLDesign.textMuted,
height: 1.4,
),
),
const SizedBox(height: 28),
FilledButton(
onPressed: () => showParentUpgradePrompt(
context,
title: 'Unlock advanced insights',
message:
'Subscribe to see detailed behavior trends, drivers, and recommendations built from your case data.',
),
child: Text(context.tTone('viewProPlans')),
),
],
),
),
);
}

final spots = buildSpots();
final eventsList = getRecentEvents();
final actions = getRecommendations();

return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(title: const Text("Custody Risk")),
body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// 🔥 SCORE CARD
Container(
padding: const EdgeInsets.all(22),
decoration: const BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
boxShadow: PLDesign.softShadow,
),
child: Column(
children: [
Container(
height: 10,
width: 10,
decoration: BoxDecoration(
color: color(),
shape: BoxShape.circle,
),
),
const SizedBox(height: 10),
const Text("Interaction Score",
style: PLDesign.caption),
const SizedBox(height: 10),
Text(
score.toString(),
style: const TextStyle(
fontSize: 42, fontWeight: FontWeight.w900),
),
Text(label(), style: PLDesign.caption),
const SizedBox(height: 10),

/// ⚠️ LEGAL SAFE LINE
Text(
"Based on recorded events. Not a legal determination.",
style: PLDesign.caption.copyWith(fontSize: 11),
),
],
),
),

const SizedBox(height: 20),

/// 📈 GRAPH
Container(
height: 220,
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
boxShadow: [
BoxShadow(
color: PLDesign.primary.withOpacity(.2),
blurRadius: 20,
)
],
),
child: LineChart(
LineChartData(
gridData: const FlGridData(show: false),
borderData: FlBorderData(show: false),
titlesData: const FlTitlesData(show: false),
lineBarsData: [
LineChartBarData(
spots:
spots.isEmpty ? [const FlSpot(0, 20)] : spots,
isCurved: true,
barWidth: 3,
dotData: const FlDotData(show: true),
)
],
),
),
),

const SizedBox(height: 20),

/// ⚠️ EVENTS
Container(
padding: const EdgeInsets.all(18),
decoration: const BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
boxShadow: PLDesign.softShadow,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text("Recent Recorded Events",
style: PLDesign.sectionTitle),
const SizedBox(height: 12),

if (eventsList.isEmpty)
const Text("No recent events",
style: PLDesign.caption),

...eventsList.map((e) {
return Padding(
padding: const EdgeInsets.only(bottom: 8),
child: Text(
"${e["type"]} (Severity ${e["severity"]})",
style: PLDesign.body,
),
);
}),
],
),
),

const SizedBox(height: 20),

/// 🎯 ACTIONS
Container(
padding: const EdgeInsets.all(18),
decoration: const BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
boxShadow: PLDesign.softShadow,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text("Suggested Documentation Practices",
style: PLDesign.sectionTitle),
const SizedBox(height: 12),

...actions.map((a) => Padding(
padding: const EdgeInsets.only(bottom: 8),
child: Text("• $a", style: PLDesign.body),
)),
],
),
),

const SizedBox(height: 20),

/// 📄 EXPORT BUTTON
ElevatedButton(
onPressed: generateSummary,
child: const Text("Generate Court Summary"),
),
],
),
);
}
}
