import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../design/design.dart';
import '../../services/tamper_proof_service.dart';
import '../../services/court_pdf_service.dart';
import 'pdf_preview_screen.dart';

class CourtSummaryScreen extends StatefulWidget {
const CourtSummaryScreen({super.key});

@override
State<CourtSummaryScreen> createState() => _CourtSummaryScreenState();
}

class _CourtSummaryScreenState extends State<CourtSummaryScreen> {
bool loading = true;
bool error = false;
bool isTampered = false;

int exchanges = 0;
int violations = 0;
int proposals = 0;
int messages = 0;
int expenses = 0;
int documents = 0;

List<QueryDocumentSnapshot> violationEvents = [];

int complianceScore = 100;

@override
void initState() {
super.initState();
loadData();
}

/// ================================
/// 🔥 LOAD DATA (UPGRADED)
/// ================================
Future<void> loadData() async {
try {
final uid = FirebaseAuth.instance.currentUser!.uid;
final db = FirebaseFirestore.instance;

final userSnap = await db.collection("users").doc(uid).get();
final activeCaseId = (userSnap.data()?["caseId"] ?? "").toString();

final results = await Future.wait([
db.collection("riskEvents")
.where("userId", isEqualTo: uid)
.orderBy("timestamp")
.get(),
db.collection("messages").where("userId", isEqualTo: uid).get(),
db.collection("expenses").where("userId", isEqualTo: uid).get(),
db.collection("documents").where("userId", isEqualTo: uid).get(),
]);

final proposalsSnap = activeCaseId.isNotEmpty
    ? await db.collection("proposals").where("caseId", isEqualTo: activeCaseId).get()
    : await db.collection("proposals").limit(0).get();

final eventsSnap = results[0] as QuerySnapshot;
final messagesSnap = results[1] as QuerySnapshot;
final expensesSnap = results[2] as QuerySnapshot;
final documentsSnap = results[3] as QuerySnapshot;

exchanges = eventsSnap.docs.length;

violationEvents = eventsSnap.docs.where((d) {
final type = (d.data() as Map<String, dynamic>)["type"] ?? "";
return type == "missed_exchange" ||
type == "late" ||
type == "message_conflict";
}).toList();

violations = violationEvents.length;

proposals = proposalsSnap.docs.length;
messages = messagesSnap.docs.length;
expenses = expensesSnap.docs.length;
documents = documentsSnap.docs.length;

/// 🔒 VERIFY TAMPER CHAIN
final eventsData =
eventsSnap.docs.map((e) => e.data() as Map<String, dynamic>).toList();

isTampered = !TamperProofService.verifyChain(eventsData);

complianceScore = calculateCompliance();

if (mounted) {
setState(() => loading = false);
}
} catch (e) {
if (mounted) {
setState(() {
loading = false;
error = true;
});
}
}
}

/// ================================
/// 🧠 COMPLIANCE LOGIC
/// ================================
int calculateCompliance() {
int score = 100;
score -= violations * 5;
return score.clamp(0, 100);
}

/// ================================
/// 🧠 NARRATIVE
/// ================================
String buildNarrative() {
if (violations == 0) {
return "No violations recorded. Consistent compliance observed across documented events.";
}

if (violations < 3) {
return "Minor inconsistencies observed. Overall compliance remains stable with isolated deviations.";
}

return "Repeated deviations from expected schedule detected. Continued documentation recommended.";
}

/// ================================
/// 📄 EXPORT PDF
/// ================================
Future<void> exportPdf() async {
final eventsData = violationEvents.map((e) {
final d = e.data() as Map<String, dynamic>;
return {
"type": d["type"],
"severity": d["severity"] ?? 1,
};
}).toList();

final bytes = await CourtPdfService.buildCourtSummaryPdfBytes(
complianceScore: complianceScore,
exchanges: exchanges,
violations: violations,
proposals: proposals,
messages: messages,
expenses: expenses,
documents: documents,
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
}

/// ================================
/// 🧱 METRIC TILE
/// ================================
Widget metricTile(String label, int value, Color color) {
return Expanded(
child: Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
),
child: Column(
children: [
Text(
value.toString(),
style: TextStyle(
fontSize: 22,
fontWeight: FontWeight.w900,
color: color,
),
),
const SizedBox(height: 4),
Text(label, style: PLDesign.caption),
],
),
),
);
}

/// ================================
/// ⚠️ EVENT TILE
/// ================================
Widget violationTile(Map<String, dynamic> data) {
final type = data["type"] ?? "";
final ts = data["timestamp"] as Timestamp?;

final date =
ts != null ? "${ts.toDate().month}/${ts.toDate().day}" : "";

return Container(
margin: const EdgeInsets.only(bottom: 10),
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
),
child: Row(
children: [
const Icon(Icons.warning, color: Colors.orange, size: 18),
const SizedBox(width: 10),
Expanded(
child: Text(
type,
style: PLDesign.body.copyWith(fontWeight: FontWeight.w700),
),
),
Text(date, style: PLDesign.caption),
],
),
);
}

/// ================================
/// 🧱 BUILD
/// ================================
@override
Widget build(BuildContext context) {
if (loading) {
return const Scaffold(
body: Center(child: CircularProgressIndicator()),
);
}

if (error) {
return const Scaffold(
body: Center(child: Text("Failed to load data")),
);
}

return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(title: const Text("Court Summary")),
body: ListView(
padding: const EdgeInsets.all(20),
children: [

/// 🔒 TAMPER WARNING (ONLY IF NEEDED)
if (isTampered)
Container(
margin: const EdgeInsets.only(bottom: 16),
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: Colors.red.withValues(alpha:.1),
borderRadius: BorderRadius.circular(14),
),
child: const Text(
"⚠️ Data integrity warning: activity log inconsistency detected.",
style: TextStyle(color: Colors.red),
),
),

/// HEADER (UNCHANGED STYLE)
Container(
padding: const EdgeInsets.all(22),
decoration: const BoxDecoration(
color: PLDesign.primary,
borderRadius: PLDesign.r20,
boxShadow: PLDesign.softShadow,
),
child: Row(
children: [
const Icon(Icons.gavel, color: Colors.white, size: 34),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text("Compliance Score",
style: TextStyle(color: Colors.white70)),
const SizedBox(height: 4),
Text(
"$complianceScore%",
style: const TextStyle(
fontSize: 34,
fontWeight: FontWeight.w900,
color: Colors.white,
),
),
],
),
),
],
),
),

const SizedBox(height: 20),

/// METRICS (UNCHANGED)
Row(
children: [
metricTile("Exchanges", exchanges, Colors.blue),
const SizedBox(width: 10),
metricTile("Violations", violations, Colors.red),
const SizedBox(width: 10),
metricTile("Proposals", proposals, Colors.orange),
],
),

const SizedBox(height: 10),

Row(
children: [
metricTile("Messages", messages, Colors.purple),
const SizedBox(width: 10),
metricTile("Expenses", expenses, Colors.green),
const SizedBox(width: 10),
metricTile("Documents", documents, Colors.teal),
],
),

const SizedBox(height: 24),

/// EVENTS (UNCHANGED)
const Text("Recorded Events", style: PLDesign.sectionTitle),
const SizedBox(height: 12),

if (violationEvents.isEmpty)
const Text("No recent events", style: PLDesign.caption),

...violationEvents
.take(5)
.map((e) => violationTile(e.data() as Map<String, dynamic>)),

const SizedBox(height: 24),

/// NARRATIVE (UNCHANGED + SAFE)
Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text("Case Summary", style: PLDesign.sectionTitle),
const SizedBox(height: 8),
Text(buildNarrative(), style: PLDesign.body),
const SizedBox(height: 10),
const Text(
"Generated from recorded events. Not a legal determination.",
style: TextStyle(fontSize: 11, color: Colors.grey),
)
],
),
),

const SizedBox(height: 24),

/// ACTIONS (UPGRADED)
Row(
children: [
Expanded(
child: ElevatedButton(
onPressed: () {},
child: const Text("Timeline Replay"),
),
),
const SizedBox(width: 12),
Expanded(
child: OutlinedButton(
onPressed: exportPdf,
child: const Text("Export Court Packet"),
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
