import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class ExportRow {
  const ExportRow({
    required this.type,
    required this.date,
    required this.description,
    this.amount,
    this.tags = const [],
    this.evidence = false,
  });

  final String type;
  final DateTime? date;
  final String description;
  final double? amount;
  final List<String> tags;
  final bool evidence;
}

class ExportService {
  ExportService._();

  static Future<Uint8List> buildPdf({
    required String caseTitle,
    required int childrenCount,
    required List<ExportRow> rows,
  }) async {
    final doc = pw.Document();
    final df = DateFormat.yMMMd().add_jm();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'ParentLedger Case Export',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Case: $caseTitle'),
          pw.Text('Children: $childrenCount'),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(3.6),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: _cells(
                  const ['Type', 'Date', 'Description', 'Amount', 'Tags'],
                  bold: true,
                ),
              ),
              ...rows.map((r) => pw.TableRow(
                    children: _cells([
                      r.type,
                      r.date != null ? df.format(r.date!.toLocal()) : '—',
                      '${r.description}${r.evidence ? ' [Evidence]' : ''}',
                      r.amount != null ? r.amount!.toStringAsFixed(2) : '',
                      r.tags.join(', '),
                    ]),
                  )),
            ],
          ),
        ],
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  static Uint8List buildCsv(List<ExportRow> rows) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final buffer = StringBuffer('type,date,description,amount,tags,evidence\n');
    for (final row in rows) {
      final date = row.date != null ? df.format(row.date!.toLocal()) : '';
      buffer.writeln([
        _csvEsc(row.type),
        _csvEsc(date),
        _csvEsc(row.description),
        row.amount?.toStringAsFixed(2) ?? '',
        _csvEsc(row.tags.join('|')),
        row.evidence ? 'true' : 'false',
      ].join(','));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static List<pw.Widget> _cells(List<String> values, {bool bold = false}) {
    return values
        .map(
          (v) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(
              v,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        )
        .toList();
  }

  static String _csvEsc(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
