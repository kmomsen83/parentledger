import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'court_case_export_screen.dart';

class LegalHubScreen extends StatefulWidget {
final String? summaryId;

const LegalHubScreen({
super.key,
this.summaryId,
});

@override
State<LegalHubScreen> createState() => _LegalHubScreenState();
}

class _LegalHubScreenState extends State<LegalHubScreen> {
Map<String, dynamic>? summary;
bool loading = true;

/// ================================
/// 🔥 LOAD SUMMARY
/// ================================
Future<void> loadSummary() async {
try {
final user = FirebaseAuth.instance.currentUser;
if (user == null) return;

final db = FirebaseFirestore.instance;

final userDoc =
await db.collection("users").doc(user.uid).get();

final caseId = userDoc.data()?["caseId"];
if (caseId == null) return;

/// IF summaryId passed → load specific
if (widget.summaryId != null) {
final doc = await db
.collection("cases")
.doc(caseId)
.collection("legalSummaries")
.doc(widget.summaryId)
.get();

summary = doc.data();
} else {
/// Otherwise → load latest
final snap = await db
.collection("cases")
.doc(caseId)
.collection("legalSummaries")
.orderBy("createdAt", descending: true)
.limit(1)
.get();

if (snap.docs.isNotEmpty) {
summary = snap.docs.first.data();
}
}

setState(() => loading = false);
} catch (e) {
setState(() => loading = false);
}
}

@override
void initState() {
super.initState();
loadSummary();
}

/// ================================
/// 🧱 TILE
/// ================================
Widget tile({
required IconData icon,
required String title,
required String desc,
required VoidCallback onTap,
}) {
return GestureDetector(
onTap: onTap,
child: Container(
margin: const EdgeInsets.only(bottom: 18),
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: Row(
children: [
Icon(icon, color: PLDesign.primary, size: 26),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(title, style: PLDesign.sectionTitle),
const SizedBox(height: 4),
Text(desc, style: PLDesign.caption),
],
),
),
const Icon(Icons.chevron_right,
color: PLDesign.textMuted),
],
),
),
);
}

/// ================================
/// 🧠 SUMMARY CARD
/// ================================
Widget summaryCard() {
if (loading) {
return const Padding(
padding: EdgeInsets.all(30),
child: Center(child: CircularProgressIndicator()),
);
}

if (summary == null) {
return Container(
padding: const EdgeInsets.all(20),
decoration: const BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
),
child: const Text("No legal summary available"),
);
}

final text = summary!["summaryText"] ?? "";
final risk = summary!["riskScore"] ?? 0;
final ts = summary!["createdAt"];

DateTime? date;
if (ts != null && ts is Timestamp) {
date = ts.toDate();
}

return Container(
padding: const EdgeInsets.all(20),
margin: const EdgeInsets.only(bottom: 20),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

/// HEADER
Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
const Text(
"Latest Legal Summary",
style: PLDesign.sectionTitle,
),
Text(
"Risk: $risk",
style: const TextStyle(
color: Colors.orange),
),
],
),

const SizedBox(height: 10),

if (date != null)
Text(
"${date.toLocal()}",
style: PLDesign.caption,
),

const SizedBox(height: 14),

Text(
text,
style: const TextStyle(height: 1.4),
),
],
),
);
}

/// ================================
/// 🔄 REGENERATE SUMMARY
/// ================================
Future<void> regenerateSummary() async {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Regenerating summary...")),
);

/// 👉 You can call your AI generator again here later
}

/// ================================
/// 🧱 BUILD
/// ================================
@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.transparent,
appBar: AppBar(
title: const Text("Legal Hub"),
actions: [
IconButton(
icon: const Icon(Icons.refresh),
onPressed: regenerateSummary,
)
],
),
body: PLDesign.screen(
title: "Legal Tools",
child: Column(
children: [

/// 🔥 SUMMARY
summaryCard(),

/// EXPORTS
tile(
icon: Icons.picture_as_pdf,
title: "Full Case Export",
desc:
"Generate complete court-ready report",
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
const CourtCaseExportScreen(),
),
);
},
),

tile(
icon: Icons.timeline,
title: "Timeline Export",
desc: "Chronological custody events",
onTap: () {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Coming soon")),
);
},
),

tile(
icon: Icons.warning_amber_rounded,
title: "Violation Report",
desc:
"Missed exchanges & compliance issues",
onTap: () {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Coming soon")),
);
},
),
],
),
),
);
}
}
