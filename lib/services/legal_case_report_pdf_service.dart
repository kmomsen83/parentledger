import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/case_event.dart';
import 'case_event_service.dart';
import 'case_expense_service.dart';
import 'timeline_actor_resolver.dart' show TimelineActor;

/// Court-oriented PDF: chronological record, financial table, consistent headers/footers.
class LegalCaseReportPdfService {
  LegalCaseReportPdfService._();

  static final _dateTimeFmt = DateFormat("MMMM d, yyyy · h:mm a");
  static final _tableDateFmt = DateFormat.yMMMd();

  static const double _marginPt = 18;

  /// Builds a multi-page letter PDF from live Firestore data for [caseId].
  static Future<Uint8List> buildPdfBytes(String caseId) async {
    await _ensureCaseEventsBackfill(caseId);

    final db = FirebaseFirestore.instance;
    final caseSnap = await db.collection('cases').doc(caseId).get();
    final memberIds = List<String>.from(caseSnap.data()?['memberIds'] ?? []);

    final actors = await TimelineActor.loadMany(memberIds);
    final partyLine = _formatParties(memberIds, actors);

    final events = await CaseEventService.fetchCaseEvents(caseId);
    final actorMap = await TimelineActor.loadMany(
      events.map((e) => e.createdBy).where((u) => u.isNotEmpty),
    );

    final expensesSnap = await CaseExpenseService.expensesCol(caseId).get();
    final expenseRows = expensesSnap.docs.map((d) {
      final m = d.data();
      return LegalCaseExpensePdfRow.fromDoc(d.id, m);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final generatedAt = DateTime.now();

    final msgCount = events.where((e) => e.isMessageLike).length;
    final expCount = expenseRows.length;
    final scheduleCount = events.where((e) => e.isScheduleLike).length;

    final dateRangeStr = _dateRangeLabel(events);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(_marginPt),
        maxPages: 5000,
        header: (ctx) => buildHeader(
          caseId: caseId,
          generatedAt: generatedAt,
          partiesLine: partyLine,
        ),
        footer: (ctx) => buildFooter(ctx),
        build: (ctx) => [
          _sectionTitle('Case Summary'),
          pw.SizedBox(height: 6),
          _summaryBody(
            totalMessages: msgCount,
            totalExpenses: expCount,
            totalScheduledEvents: scheduleCount,
            dateRange: dateRangeStr,
          ),
          pw.SizedBox(height: 14),
          pw.Divider(thickness: 0.75, color: PdfColors.grey400),
          pw.SizedBox(height: 14),
          _sectionTitle('Chronological Record of Events'),
          pw.SizedBox(height: 8),
          ...buildTimeline(events, actorMap, expenseRows),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 0.75, color: PdfColors.grey400),
          pw.SizedBox(height: 14),
          _sectionTitle('Financial Summary'),
          pw.SizedBox(height: 8),
          buildExpenseTable(expenseRows),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 0.75, color: PdfColors.grey400),
          pw.SizedBox(height: 14),
          _sectionTitle('Communication Overview'),
          pw.SizedBox(height: 8),
          _communicationOverview(totalMessages: msgCount),
        ],
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static Future<void> _ensureCaseEventsBackfill(String caseId) async {
    var list = await CaseEventService.fetchCaseEvents(caseId);
    if (list.isEmpty) {
      await CaseEventService.backfillCaseEvents(caseId);
    }
  }

  static String _formatParties(
    List<String> memberIds,
    Map<String, TimelineActor> actors,
  ) {
    if (memberIds.isEmpty) return 'Parties: not specified';
    final a = memberIds.isNotEmpty ? (actors[memberIds.first]?.fullName ?? 'Parent A') : 'Parent A';
    final b = memberIds.length > 1
        ? (actors[memberIds[1]]?.fullName ?? 'Parent B')
        : 'Parent B';
    return '$a vs $b';
  }

  static String _dateRangeLabel(List<CaseEvent> events) {
    if (events.isEmpty) return 'No dated entries';
    final dates = events.map((e) => e.timestamp).toList();
    dates.sort();
    final start = dates.first;
    final end = dates.last;
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return _dateTimeFmt.format(start.toLocal());
    }
    return '${_dateTimeFmt.format(start.toLocal())} — ${_dateTimeFmt.format(end.toLocal())}';
  }

  /// Repeating page header (court-style masthead).
  static pw.Widget buildHeader({
    required String caseId,
    required DateTime generatedAt,
    required String partiesLine,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ParentLedger',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Court Communication & Activity Report',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Case ID: $caseId', style: _metaStyle()),
        pw.Text(
          'Generated: ${_dateTimeFmt.format(generatedAt.toLocal())}',
          style: _metaStyle(),
        ),
        pw.Text('Parties: $partiesLine', style: _metaStyle()),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 0.5, color: PdfColors.grey500),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.TextStyle _metaStyle() =>
      const pw.TextStyle(fontSize: 9, lineSpacing: 1.2);

  /// Page footer with disclaimer and pagination (use inside [pw.MultiPage.footer]).
  static pw.Widget buildFooter(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey500),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Generated by ParentLedger',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'This document is a system-generated record of activity.',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'All timestamps are recorded automatically and cannot be altered.',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  static pw.Widget _summaryBody({
    required int totalMessages,
    required int totalExpenses,
    required int totalScheduledEvents,
    required String dateRange,
  }) {
    return pw.DefaultTextStyle(
      style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.35),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Total messages: $totalMessages'),
          pw.Text('Total expenses: $totalExpenses'),
          pw.Text('Total scheduled events: $totalScheduledEvents'),
          pw.SizedBox(height: 4),
          pw.Text('Date range covered: $dateRange'),
        ],
      ),
    );
  }

  /// Chronological blocks for the narrative section (newest sort comes from [events] order).
  static List<pw.Widget> buildTimeline(
    List<CaseEvent> events,
    Map<String, TimelineActor> actors,
    List<LegalCaseExpensePdfRow> expenseRows,
  ) {
    if (events.isEmpty) {
      return [
        pw.Text(
          'No events recorded for this case.',
          style: pw.TextStyle(
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey700,
          ),
        ),
      ];
    }

    final out = <pw.Widget>[];
    for (final e in events) {
      out.add(_timelineEntry(e, actors, expenseRows));
      out.add(pw.SizedBox(height: 10));
    }
    return out;
  }

  static String _typeLabel(String raw) {
    switch (raw) {
      case CaseEventTypes.message:
        return 'Message';
      case CaseEventTypes.expenseCreated:
      case CaseEventTypes.expenseApproved:
      case CaseEventTypes.expenseDenied:
      case 'expense':
        return 'Expense';
      case CaseEventTypes.scheduleCreated:
      case CaseEventTypes.scheduleUpdated:
      case 'exchange':
        return 'Schedule';
      case CaseEventTypes.statusChange:
      case 'document':
        return 'Status Update';
      default:
        if (raw.isEmpty) return 'Event';
        return raw.substring(0, 1).toUpperCase() + raw.substring(1);
    }
  }

  static pw.Widget _timelineEntry(
    CaseEvent e,
    Map<String, TimelineActor> actors,
    List<LegalCaseExpensePdfRow> expenseRows,
  ) {
    final when = _dateTimeFmt.format(e.timestamp.toLocal());
    final typeLine = _typeLabel(e.type);
    final senderName = e.createdBy.isEmpty
        ? 'Unknown'
        : (actors[e.createdBy]?.fullName ?? 'Participant');

    final detailChildren = <pw.Widget>[];

    if (e.isMessageLike) {
      final text = e.description.isNotEmpty
          ? e.description
          : (e.metadata['text'] ?? '').toString();
      detailChildren.addAll([
        pw.Text('DETAILS:', style: _detailLabelStyle()),
        pw.SizedBox(height: 2),
        pw.Bullet(text: 'Sender: $senderName'),
        pw.Bullet(
          text: 'Content: ${text.isEmpty ? '(no text)' : text}',
        ),
      ]);
    } else if (e.isExpenseLike) {
      final id = (e.metadata['expenseId'] ?? '').toString();
      LegalCaseExpensePdfRow? row;
      for (final r in expenseRows) {
        if (r.id == id) {
          row = r;
          break;
        }
      }
      final title = row?.title ?? (e.metadata['title'] ?? e.metadata['description'] ?? '').toString();
      final amount = row?.amount ?? _readAmount(e.metadata['amount']);
      final status = row?.displayStatus ??
          (e.metadata['status']?.toString().isNotEmpty == true
              ? e.metadata['status'].toString()
              : _expenseStatusFromEventData(e.metadata));
      detailChildren.addAll([
        pw.Text('DETAILS:', style: _detailLabelStyle()),
        pw.SizedBox(height: 2),
        pw.Bullet(text: 'Title: ${title.isEmpty ? '(untitled)' : title}'),
        pw.Bullet(text: 'Amount: \$${amount.toStringAsFixed(2)}'),
        pw.Bullet(text: 'Status: $status'),
      ]);
    } else if (e.isScheduleLike) {
      final scheduledRaw = e.metadata['scheduledTime'] ?? e.metadata['time'];
      DateTime scheduled;
      if (scheduledRaw is String) {
        scheduled = DateTime.tryParse(scheduledRaw) ?? e.timestamp;
      } else {
        scheduled = e.timestamp;
      }
      final location = (e.metadata['location'] ?? e.metadata['locationName'] ?? '').toString();
      final exType = (e.metadata['exchangeType'] ?? '').toString();
      final title = [exType, location].where((s) => s.isNotEmpty).join(' · ');
      detailChildren.addAll([
        pw.Text('DETAILS:', style: _detailLabelStyle()),
        pw.SizedBox(height: 2),
        pw.Bullet(text: 'Event: ${title.isEmpty ? e.title.isNotEmpty ? e.title : 'Scheduled exchange' : title}'),
        pw.Bullet(text: 'Time: ${_dateTimeFmt.format(scheduled.toLocal())}'),
      ]);
    } else if (e.type == 'document') {
      final name = (e.metadata['fileName'] ?? '').toString();
      final docType = (e.metadata['documentType'] ?? '').toString();
      detailChildren.addAll([
        pw.Text('DETAILS:', style: _detailLabelStyle()),
        pw.SizedBox(height: 2),
        pw.Bullet(text: 'File: ${name.isEmpty ? '(unnamed)' : name}'),
        if (docType.isNotEmpty) pw.Bullet(text: 'Category: $docType'),
      ]);
    } else {
      final desc = e.description.isNotEmpty ? e.description : e.title;
      detailChildren.addAll([
        pw.Text('DETAILS:', style: _detailLabelStyle()),
        pw.SizedBox(height: 2),
        pw.Bullet(text: desc.isNotEmpty ? desc : '(see metadata)'),
        if (e.metadata.isNotEmpty)
          pw.Bullet(
            text: 'Metadata: ${e.metadata.toString()}',
          ),
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey400, thickness: 0.35),
        pw.SizedBox(height: 8),
        pw.Text(
          when,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: 'TYPE: ',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.TextSpan(
                text: typeLine,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        ...detailChildren,
        pw.SizedBox(height: 4),
      ],
    );
  }

  static pw.TextStyle _detailLabelStyle() => pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.2,
      );

  static double _readAmount(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _expenseStatusFromEventData(Map<String, dynamic> data) {
    final paid = data['paid'] == true;
    final s = (data['status'] ?? '').toString().toLowerCase();
    if (s == 'denied') return 'Denied';
    if (paid || s == 'paid') return 'Approved';
    return 'Pending';
  }

  /// Expense grid plus requested / approved / outstanding totals.
  static pw.Widget buildExpenseTable(List<LegalCaseExpensePdfRow> rows) {
    if (rows.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'No expenses recorded for this case.',
            style: pw.TextStyle(
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ],
      );
    }

    final totalRequested = rows.fold<double>(0, (s, r) => s + r.amount);
    final totalApproved = rows.where((r) => r.isPaid).fold<double>(0, (s, r) => s + r.amount);
    final totalOutstanding = rows.where((r) => r.isOutstanding).fold<double>(0, (s, r) => s + r.amount);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.4),
            1: pw.FlexColumnWidth(2.4),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: ['Date', 'Title', 'Amount', 'Status']
                  .map(
                    (h) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            ...rows.map(
              (r) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(_tableDateFmt.format(r.date.toLocal()), style: _cellStyle()),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(r.title, style: _cellStyle()),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('\$${r.amount.toStringAsFixed(2)}', style: _cellStyle()),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(r.displayStatus, style: _cellStyle()),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Total requested: \$${totalRequested.toStringAsFixed(2)}',
          style: _totalsStyle(),
        ),
        pw.Text(
          'Total approved: \$${totalApproved.toStringAsFixed(2)}',
          style: _totalsStyle(),
        ),
        pw.Text(
          'Total outstanding: \$${totalOutstanding.toStringAsFixed(2)}',
          style: _totalsStyle(),
        ),
      ],
    );
  }

  static pw.TextStyle _cellStyle() => const pw.TextStyle(fontSize: 9);

  static pw.TextStyle _totalsStyle() => pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      );

  static pw.Widget _communicationOverview({required int totalMessages}) {
    final main = totalMessages == 0
        ? pw.Text(
            'No messages recorded.',
            style: pw.TextStyle(
              fontSize: 10,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          )
        : pw.Text('Total messages: $totalMessages', style: const pw.TextStyle(fontSize: 10));
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        main,
        pw.SizedBox(height: 6),
        pw.Text(
          'Flagged or highlighted messages may be summarized here in a future release.',
          style: pw.TextStyle(
            fontSize: 9,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }
}

/// Firestore expense row normalized for the PDF table.
class LegalCaseExpensePdfRow {
  LegalCaseExpensePdfRow({
    required this.id,
    required this.date,
    required this.title,
    required this.amount,
    required this.statusRaw,
    required this.paid,
  });

  final String id;
  final DateTime date;
  final String title;
  final double amount;
  final String statusRaw;
  final bool paid;

  factory LegalCaseExpensePdfRow.fromDoc(String id, Map<String, dynamic> m) {
    final created = m['createdAt'];
    final date = created is Timestamp ? created.toDate() : DateTime.now();
    final amount = m['amount'] is num ? (m['amount'] as num).toDouble() : 0.0;
    final paid = m['paid'] == true || (m['status']?.toString().toLowerCase() == 'paid');
    final statusRaw = (m['status'] ?? (paid ? 'paid' : 'unpaid')).toString().toLowerCase();
    final title = (m['description'] ?? '').toString();
    return LegalCaseExpensePdfRow(
      id: id,
      date: date,
      title: title,
      amount: amount,
      statusRaw: statusRaw,
      paid: paid,
    );
  }

  String get displayStatus {
    switch (statusRaw) {
      case 'paid':
        return 'Approved';
      case 'denied':
        return 'Denied';
      case 'unpaid':
      default:
        return 'Pending';
    }
  }

  bool get isPaid => paid || statusRaw == 'paid';

  bool get isOutstanding => !isPaid && statusRaw != 'denied';
}
