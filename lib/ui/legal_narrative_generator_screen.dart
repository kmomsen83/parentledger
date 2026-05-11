import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';

class LegalNarrativeGeneratorScreen extends StatefulWidget {
const LegalNarrativeGeneratorScreen({super.key});

@override
State<LegalNarrativeGeneratorScreen> createState() =>
_LegalNarrativeGeneratorScreenState();
}

class _LegalNarrativeGeneratorScreenState
extends State<LegalNarrativeGeneratorScreen> {
DateTimeRange? dateRange;
String tone = "neutral";
bool includeDisputesOnly = false;
bool generating = false;

String? generatedText;

/// ================================
/// GENERATE NARRATIVE
/// ================================
Future<void> generateNarrative() async {
setState(() => generating = true);

await Future.delayed(const Duration(seconds: 2));

/// TODO: Replace with AI call
generatedText = """
Between March 1 and March 15, 2026, multiple co-parenting events were recorded.

A total of 12 custody exchanges occurred. On March 3, the respondent arrived 25 minutes late.

Shared expenses totaling \$420 were logged, with \$210 remaining unpaid.

All records have been documented and timestamped within the ParentLedger system.
""";

if (!mounted) return;

setState(() => generating = false);
}

/// ================================
/// DATE PICKER
/// ================================
Future<void> pickDateRange() async {
final result = await showDateRangePicker(
context: context,
firstDate: DateTime(2020),
lastDate: DateTime.now(),
);

if (result != null) {
setState(() => dateRange = result);
}
}

/// ================================
/// BUILD
/// ================================
@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(title: const Text("Narrative Generator")),
body: PLDesign.screen(
title: "Generate Legal Narrative",
child: SingleChildScrollView(
child: Column(
children: [

/// DATE RANGE
_card(
child: ListTile(
title: const Text("Date Range"),
subtitle: Text(
dateRange == null
? "Select range"
: "${dateRange!.start} → ${dateRange!.end}",
),
trailing: const Icon(Icons.calendar_today),
onTap: pickDateRange,
),
),

/// TONE
_card(
child: DropdownButtonFormField<String>(
key: ValueKey<String>(tone),
initialValue: tone,
items: const [
DropdownMenuItem(
value: "neutral", child: Text("Neutral")),
DropdownMenuItem(
value: "formal", child: Text("Formal Legal")),
DropdownMenuItem(
value: "concise", child: Text("Concise")),
],
onChanged: (val) =>
setState(() => tone = val!),
decoration: const InputDecoration(
labelText: "Narrative Style"),
),
),

/// DISPUTE FILTER
_card(
child: SwitchListTile(
title: const Text("Only Include Disputes"),
value: includeDisputesOnly,
onChanged: (val) =>
setState(() => includeDisputesOnly = val),
),
),

/// GENERATE BUTTON
const SizedBox(height: 10),
ElevatedButton(
onPressed: generating ? null : generateNarrative,
child: generating
? const CircularProgressIndicator()
: const Text("Generate Narrative"),
),

const SizedBox(height: 20),

/// OUTPUT
if (generatedText != null)
_card(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Text(
"Generated Narrative",
style: PLDesign.sectionTitle,
),
const SizedBox(height: 10),
Text(
generatedText!,
style: const TextStyle(height: 1.5),
),

const SizedBox(height: 16),

Row(
children: [
ElevatedButton(
onPressed: () {},
child: const Text("Copy"),
),
const SizedBox(width: 10),
ElevatedButton(
onPressed: () {},
child: const Text("Export PDF"),
),
],
)
],
),
),
],
),
),
),
);
}

/// CARD WRAPPER
Widget _card({required Widget child}) {
return Container(
margin: const EdgeInsets.only(bottom: 16),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: child,
);
}
}
