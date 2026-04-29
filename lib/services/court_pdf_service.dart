import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class CourtPdfService {
static Future<void> generate({
required int complianceScore,
required int exchanges,
required int violations,
required int proposals,
required int messages,
required int expenses,
required int documents,
required List<Map<String, dynamic>> events,
required String narrative,
}) async {
final pdf = pw.Document();

final now = DateTime.now();
final formattedDate =
DateFormat('MM/dd/yyyy HH:mm').format(now);

pdf.addPage(
pw.MultiPage(
margin: const pw.EdgeInsets.all(32),
build: (context) => [

/// ================================
/// 🔷 HEADER
/// ================================
pw.Text(
"ParentLedger Court Summary",
style: pw.TextStyle(
fontSize: 22,
fontWeight: pw.FontWeight.bold,
),
),

pw.SizedBox(height: 4),

pw.Text(
"Generated: $formattedDate",
style: const pw.TextStyle(fontSize: 10),
),

pw.Divider(),

/// ================================
/// ⚖️ COMPLIANCE SCORE
/// ================================
pw.Container(
padding: const pw.EdgeInsets.all(14),
decoration: pw.BoxDecoration(
border: pw.Border.all(),
),
child: pw.Column(
crossAxisAlignment: pw.CrossAxisAlignment.start,
children: [
pw.Text(
"Compliance Score",
style: pw.TextStyle(
fontWeight: pw.FontWeight.bold),
),
pw.SizedBox(height: 6),
pw.Text(
"$complianceScore%",
style: pw.TextStyle(
fontSize: 26,
fontWeight: pw.FontWeight.bold,
),
),
],
),
),

pw.SizedBox(height: 20),

/// ================================
/// 📊 METRICS TABLE
/// ================================
pw.Text(
"Activity Metrics",
style: pw.TextStyle(
fontWeight: pw.FontWeight.bold),
),

pw.SizedBox(height: 10),

pw.Table(
border: pw.TableBorder.all(),
columnWidths: {
0: const pw.FlexColumnWidth(2),
1: const pw.FlexColumnWidth(1),
},
children: [
_row("Exchanges", exchanges),
_row("Violations", violations),
_row("Proposals", proposals),
_row("Messages", messages),
_row("Expenses", expenses),
_row("Documents", documents),
],
),

pw.SizedBox(height: 20),

/// ================================
/// ⚠️ EVENT TIMELINE
/// ================================
pw.Text(
"Recorded Events",
style: pw.TextStyle(
fontWeight: pw.FontWeight.bold),
),

pw.SizedBox(height: 10),

if (events.isEmpty)
pw.Text(
"No recorded events",
style: const pw.TextStyle(fontSize: 10),
),

...events.map((e) {
final type = e["type"] ?? "unknown";
final severity = e["severity"] ?? 1;
final date = e["date"] ?? "";

return pw.Container(
margin: const pw.EdgeInsets.only(bottom: 6),
child: pw.Text(
"- $type (severity: $severity) $date",
style: const pw.TextStyle(fontSize: 10),
),
);
}),

pw.SizedBox(height: 20),

/// ================================
/// 🧠 CASE SUMMARY
/// ================================
pw.Text(
"Case Summary",
style: pw.TextStyle(
fontWeight: pw.FontWeight.bold),
),

pw.SizedBox(height: 8),

pw.Text(
narrative,
style: const pw.TextStyle(fontSize: 11),
),

pw.SizedBox(height: 20),

/// ================================
/// 🔐 DISCLAIMER
/// ================================
pw.Text(
"This report is generated from recorded user-entered data and system logs. "
"It is intended for documentation purposes only and does not constitute legal advice or determination.",
style: const pw.TextStyle(fontSize: 9),
),
],
),
);

await Printing.layoutPdf(
onLayout: (format) async => pdf.save(),
);
}

/// Legal communication log (messages) for court documentation.
static Future<void> generateCommunicationLog({
required String conversationTitle,
required String generatedAtLabel,
required List<Map<String, String>> entries,
String? caseId,
}) async {
final pdf = pw.Document();

pdf.addPage(
pw.MultiPage(
margin: const pw.EdgeInsets.all(32),
build: (context) => [
pw.Text(
'Communication log',
style: pw.TextStyle(
fontSize: 20,
fontWeight: pw.FontWeight.bold,
),
),
pw.SizedBox(height: 8),
pw.Text(
'Neutral record',
style: pw.TextStyle(
fontSize: 11,
fontWeight: pw.FontWeight.bold,
),
),
pw.SizedBox(height: 4),
pw.Text(
'Generated: $generatedAtLabel',
style: const pw.TextStyle(fontSize: 10),
),
pw.SizedBox(height: 2),
pw.Text(
'Messages reviewed: ${entries.length}',
style: const pw.TextStyle(fontSize: 10),
),
pw.SizedBox(height: 2),
pw.Text(
conversationTitle,
style: const pw.TextStyle(fontSize: 9),
),
pw.Divider(),
pw.SizedBox(height: 14),
if (entries.isEmpty)
pw.Text(
'No messages in this export.',
style: const pw.TextStyle(fontSize: 10),
)
else
...entries.map((e) {
final date = e['date'] ?? e['header'] ?? '';
final senderId = e['senderId'] ?? 'unknown';
final message = e['message'] ?? e['body'] ?? '';
return pw.Container(
margin: const pw.EdgeInsets.only(bottom: 10),
padding: const pw.EdgeInsets.all(12),
decoration: pw.BoxDecoration(
border: pw.Border.all(width: 0.6, color: PdfColors.grey500),
borderRadius: pw.BorderRadius.circular(6),
),
child: pw.Column(
crossAxisAlignment: pw.CrossAxisAlignment.start,
children: [
pw.Text(
'$date\nSender ID: $senderId',
style: pw.TextStyle(
fontSize: 10,
fontWeight: pw.FontWeight.bold,
),
),
pw.SizedBox(height: 8),
pw.Text(
'Message:\n"$message"',
style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
),
],
),
);
}),
pw.SizedBox(height: 20),
pw.Divider(color: PdfColors.grey500),
pw.SizedBox(height: 8),
pw.Text(
'Generated by ParentLedger\n'
'Case ID: ${caseId ?? 'N/A'}\n'
'Report generated: $generatedAtLabel\n\n'
'This document is a neutral, system-generated summary of recorded communications.\n'
'No interpretation or modification has been applied.',
style: const pw.TextStyle(fontSize: 8, lineSpacing: 2),
),
],
),
);

await Printing.layoutPdf(
onLayout: (format) async => pdf.save(),
);
}

/// ================================
/// 📊 TABLE ROW HELPER
/// ================================
static pw.TableRow _row(String label, int value) {
return pw.TableRow(
children: [
pw.Padding(
padding: const pw.EdgeInsets.all(6),
child: pw.Text(label),
),
pw.Padding(
padding: const pw.EdgeInsets.all(6),
child: pw.Text(value.toString()),
),
],
);
}
}
