import 'dart:io';
import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

class GeneratingExportScreen extends StatefulWidget {
const GeneratingExportScreen({super.key});

@override
State<GeneratingExportScreen> createState() =>
_GeneratingExportScreenState();
}

class _GeneratingExportScreenState
extends State<GeneratingExportScreen> {

double progress = 0.0;
String status = "Initializing...";

String? filePath;

@override
void initState() {
super.initState();
runExport();
}

/// ================================
/// MAIN FLOW
/// ================================
Future<void> runExport() async {
await Future.delayed(const Duration(milliseconds: 400));

/// 1️⃣ AI NARRATIVE
setState(() {
progress = 0.2;
status = "Analyzing behavioral patterns...";
});

final narrative = await buildNarrative();

/// 2️⃣ PDF GENERATION
setState(() {
progress = 0.5;
status = "Building court report...";
});

final file = await generatePdf(narrative);

/// 3️⃣ SAVE / STORE
setState(() {
progress = 0.8;
status = "Saving export...";
});

await saveExport(file);

/// 4️⃣ DONE
setState(() {
progress = 1.0;
status = "Export Ready";
filePath = file.path;
});
}

/// ================================
/// AI NARRATIVE (SIMULATED)
/// ================================
Future<String> buildNarrative() async {
await Future.delayed(const Duration(seconds: 1));

return """
Behavioral Summary:

The reporting period shows moderate compliance with scheduled custody exchanges.
Two missed exchanges were detected along with delayed communication patterns.

Financial activity indicates consistent expense submissions with minor disputes.

Overall risk level: MODERATE.

Recommendation:
Maintain structured communication and reinforce exchange punctuality.
""";
}

/// ================================
/// PDF GENERATION
/// ================================
Future<File> generatePdf(String narrative) async {
final pdf = pw.Document();

pdf.addPage(
pw.MultiPage(
build: (context) => [

pw.Text("Court Case Report",
style: const pw.TextStyle(fontSize: 24)),

pw.SizedBox(height: 20),

pw.Text("AI Narrative",
style: const pw.TextStyle(fontSize: 18)),

pw.SizedBox(height: 10),

pw.Text(narrative),

pw.SizedBox(height: 20),

pw.Text("Generated: ${DateTime.now()}"),
],
),
);

final dir = await getApplicationDocumentsDirectory();
final file = File("${dir.path}/court_export_${DateTime.now().millisecondsSinceEpoch}.pdf");

await file.writeAsBytes(await pdf.save());

return file;
}

/// ================================
/// SAVE EXPORT (LOCAL NOW → FIREBASE LATER)
/// ================================
Future<void> saveExport(File file) async {
await Future.delayed(const Duration(seconds: 1));

/// 👉 later:
/// upload to Firebase Storage
/// save metadata in Firestore
}

/// ================================
/// UI
/// ================================
@override
Widget build(BuildContext context) {
final isDone = progress >= 1.0;

return Scaffold(
backgroundColor: Colors.transparent,
appBar: AppBar(
title: const Text("Generating Export"),
),

body: PLDesign.screen(
title: "",
child: Column(
children: [

const SizedBox(height: 40),

Icon(
isDone ? Icons.check_circle : Icons.gavel,
color: isDone ? PLDesign.success : PLDesign.primary,
size: 60,
),

const SizedBox(height: 20),

Text(
isDone ? "Export Ready" : "Building Report",
style: PLDesign.heroTitle,
),

const SizedBox(height: 10),

Text(
status,
style: PLDesign.caption,
textAlign: TextAlign.center,
),

const SizedBox(height: 30),

/// PROGRESS BAR
LinearProgressIndicator(
value: progress,
backgroundColor: PLDesign.border,
color: PLDesign.primary,
minHeight: 8,
),

const SizedBox(height: 40),

/// DONE ACTIONS
if (isDone && filePath != null) ...[

PLDesign.primaryButton(
label: "View File Path",
onTap: () {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(filePath!)),
);
},
),

const SizedBox(height: 12),

PLDesign.primaryButton(
label: "Done",
onTap: () {
Navigator.pop(context);
},
),
]
],
),
),
);
}
}
