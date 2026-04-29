import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parentledger/design/design.dart';
import 'package:parentledger/providers/case_context.dart';
import 'package:parentledger/services/case_switcher_service.dart';
import 'package:parentledger/services/legal_export_service.dart';
import 'package:parentledger/ui/legal_export_preview_screen.dart';
import 'package:parentledger/ui/widgets/parent_upgrade_prompt.dart';

class CourtCaseExportScreen extends StatefulWidget {
const CourtCaseExportScreen({super.key});

@override
State<CourtCaseExportScreen> createState() =>
_CourtCaseExportScreenState();
}

class _CourtCaseExportScreenState
extends State<CourtCaseExportScreen> {

bool timeline = true;
bool parenting = true;
bool expenses = true;
bool messages = true;
bool violations = true;
bool aiNarrative = true;

String range = "Last 90 Days";

bool isGenerating = false;

/// ================================
/// VALIDATION
/// ================================
bool get canGenerate {
return timeline ||
parenting ||
expenses ||
messages ||
violations ||
aiNarrative;
}

/// ================================
/// GENERATE EXPORT
/// ================================
Future<void> generateExport() async {
if (!canGenerate) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text("Select at least one module"),
),
);
return;
}

final session = context.read<CaseContext>();
if (!session.isAttorney && !session.unlockedParentPremiumFeatures) {
  await showParentUpgradePrompt(
    context,
    title: 'Upgrade for court exports',
    message:
        'Full bundle exports and court-formatted reports are included with ParentLedger Pro.',
  );
  return;
}
final caseId = session.isAttorney
    ? (context.read<CaseSwitcherService>().selectedCaseId ?? session.caseId)
    : session.caseId;
if (caseId == null || caseId.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No case selected. Open a case and try again.')),
  );
  return;
}

setState(() => isGenerating = true);

try {
  final service = LegalExportService();
  final doc = await service.generateCourtBundle(
    caseId: caseId,
    includeTimeline: timeline,
    includeParenting: parenting,
    includeExpenses: expenses,
    includeMessages: messages,
    includeViolations: violations,
    includeAiNarrative: aiNarrative,
  );
  if (!mounted) return;
  final watermarked = session.isAttorney;
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => LegalExportPreviewScreen(
        document: doc,
        watermarked: watermarked,
      ),
    ),
  );
} catch (e, st) {
  if (kDebugMode) {
    debugPrint('Court export failed: $e\n$st');
  }
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not build export: $e')),
    );
  }
} finally {
  if (mounted) setState(() => isGenerating = false);
}
}

/// ================================
/// COMPONENTS
/// ================================
Widget header() {
return Container(
padding: const EdgeInsets.all(22),
decoration: PLDesign.legalCard,
child: const Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

Row(
children: [
Icon(Icons.gavel, color: PLDesign.primary),
SizedBox(width: 10),
Text(
"Court Case Export",
style: PLDesign.sectionTitle,
),
],
),

SizedBox(height: 10),

Text(
"Generate a structured, court-ready report including timeline events, violations, financials, and AI-powered behavioral analysis.",
style: PLDesign.legalBody,
),
],
),
);
}

Widget toggleTile(
String title,
String subtitle,
bool value,
Function(bool) onChanged,
IconData icon,
) {
return Container(
margin: const EdgeInsets.only(bottom: 14),
padding: const EdgeInsets.all(18),
decoration: PLDesign.exportTileDecoration,
child: Row(
children: [

Icon(icon, color: PLDesign.primary),

const SizedBox(width: 14),

Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(title, style: PLDesign.sectionTitle),
const SizedBox(height: 4),
Text(subtitle, style: PLDesign.caption),
],
),
),

Switch(
value: value,
activeThumbColor: PLDesign.primary,
onChanged: onChanged,
)
],
),
);
}

Widget rangeSelector() {
return Container(
margin: const EdgeInsets.only(bottom: 20),
padding: const EdgeInsets.all(20),
decoration: PLDesign.legalCard,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

const Text(
"Export Time Range",
style: PLDesign.sectionTitle,
),

const SizedBox(height: 12),

DropdownButton<String>(
value: range,
isExpanded: true,
dropdownColor: PLDesign.surface,
style: const TextStyle(color: Colors.white),
underline: const SizedBox(),
items: const [
DropdownMenuItem(
value: "Last 30 Days",
child: Text("Last 30 Days")),
DropdownMenuItem(
value: "Last 90 Days",
child: Text("Last 90 Days")),
DropdownMenuItem(
value: "6 Months",
child: Text("6 Months")),
DropdownMenuItem(
value: "Full Case History",
child: Text("Full Case History")),
],
onChanged: (v) {
setState(() => range = v!);
},
)
],
),
);
}

Widget previewCard() {
return Container(
margin: const EdgeInsets.only(bottom: 20),
padding: const EdgeInsets.all(22),
decoration: PLDesign.legalCard,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

const Row(
children: [
Icon(Icons.preview, color: PLDesign.info),
SizedBox(width: 10),
Text(
"Export Preview",
style: PLDesign.sectionTitle,
),
],
),

const SizedBox(height: 14),

Text(
"Included:\n"
"${timeline ? "• Timeline Events\n" : ""}"
"${parenting ? "• Parenting Time\n" : ""}"
"${expenses ? "• Expenses\n" : ""}"
"${messages ? "• Messages\n" : ""}"
"${violations ? "• Violations\n" : ""}"
"${aiNarrative ? "• AI Narrative\n" : ""}",
style: PLDesign.legalBody,
),
],
),
);
}

Widget generateButton() {
return Column(
children: [

if (!canGenerate)
const Padding(
padding: EdgeInsets.only(bottom: 10),
child: Text(
"Select at least one section",
style: PLDesign.caption,
),
),

PLDesign.primaryButton(
label: isGenerating
? "Generating..."
: "Generate Court Report",
onTap: isGenerating
    ? () {}
    : () {
        generateExport();
      },
),
],
);
}

/// ================================
/// BUILD
/// ================================
@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.transparent,
appBar: AppBar(
title: const Text("Court Export"),
),

body: PLDesign.screen(
title: "",
child: Column(
children: [

header(),
const SizedBox(height: 20),

toggleTile(
"Timeline Events",
"Chronological custody & behavior log",
timeline,
(v) => setState(() => timeline = v),
Icons.timeline,
),

toggleTile(
"Parenting Time",
"Compliance & custody distribution",
parenting,
(v) => setState(() => parenting = v),
Icons.schedule,
),

toggleTile(
"Expenses",
"Payments, reimbursements & disputes",
expenses,
(v) => setState(() => expenses = v),
Icons.attach_money,
),

toggleTile(
"Messages",
"Communication transcript",
messages,
(v) => setState(() => messages = v),
Icons.chat,
),

toggleTile(
"Violations",
"Missed exchanges & risk flags",
violations,
(v) => setState(() => violations = v),
Icons.warning_amber_rounded,
),

toggleTile(
"AI Narrative",
"Behavior intelligence summary",
aiNarrative,
(v) => setState(() => aiNarrative = v),
Icons.psychology,
),

rangeSelector(),
previewCard(),
generateButton(),

const SizedBox(height: 40),
],
),
),
);
}
}
