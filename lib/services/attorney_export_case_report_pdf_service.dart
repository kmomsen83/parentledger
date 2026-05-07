import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/case_event.dart';
import 'ai_service.dart';
import 'case_document_service.dart';
import 'case_event_service.dart';
import 'case_messaging_service.dart';
import 'timeline_actor_resolver.dart';

/// Counsel-configured export: date range + section picks, monochrome court-style PDF.
class AttorneyExportCaseReportConfig {
  AttorneyExportCaseReportConfig({
    required this.rangeStartInclusive,
    required this.rangeEndInclusive,
    this.includeSummary = true,
    this.includeTimeline = true,
    this.includeMessages = true,
    this.includeDocuments = true,
  });

  final DateTime rangeStartInclusive;
  final DateTime rangeEndInclusive;
  final bool includeSummary;
  final bool includeTimeline;
  final bool includeMessages;
  final bool includeDocuments;

  DateTime get _startDay => DateTime(
        rangeStartInclusive.year,
        rangeStartInclusive.month,
        rangeStartInclusive.day,
      );

  DateTime get _endDay => DateTime(
        rangeEndInclusive.year,
        rangeEndInclusive.month,
        rangeEndInclusive.day,
        23,
        59,
        59,
        999,
      );

  bool _inRange(DateTime t) =>
      !t.isBefore(_startDay) && !t.isAfter(_endDay);

  bool get hasAnySection =>
      includeSummary ||
      includeTimeline ||
      includeMessages ||
      includeDocuments;
}

/// Builds a structured printable report scoped to [caseId] and [config].
class AttorneyExportCaseReportPdfService {
  AttorneyExportCaseReportPdfService._();

  static final _dateFmt = DateFormat.yMMMd();
  static final _dateTimeFmt = DateFormat('MMMM d, yyyy · h:mm a');
  static final _isoFmt = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
  static const double _margin = 54;

  static Future<void> _ensureEvents(String caseId) async {
    var list = await CaseEventService.fetchCaseEvents(caseId);
    if (list.isEmpty) {
      await CaseEventService.backfillCaseEvents(caseId);
    }
  }

  static String _childNamesLine(Map<String, dynamic>? caseMap) {
    final raw = caseMap?['children'];
    if (raw is! List) return 'Not specified on file';
    final names = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        final n = (m['name'] ??
                m['displayName'] ??
                m['firstName'] ??
                '')
            .toString()
            .trim();
        if (n.isNotEmpty) names.add(n);
      } else if (item is String && item.trim().isNotEmpty) {
        names.add(item.trim());
      }
    }
    return names.isEmpty ? 'Not specified on file' : names.join(', ');
  }

  static String _partiesVsLine(
    List<String> memberIds,
    Map<String, TimelineActor> actors,
  ) {
    if (memberIds.isEmpty) return 'Parties not specified';
    final a = actors[memberIds.first]?.fullName ?? 'Parent A';
    final b = memberIds.length > 1
        ? (actors[memberIds[1]]?.fullName ?? 'Parent B')
        : 'Parent B';
    return '$a vs $b';
  }

  static Future<Uint8List> buildPdfBytes({
    required String caseId,
    required AttorneyExportCaseReportConfig config,
  }) async {
    if (!config.hasAnySection) {
      throw ArgumentError('Select at least one section to export.');
    }

    await _ensureEvents(caseId);

    final db = FirebaseFirestore.instance;
    final caseSnap = await db.collection('cases').doc(caseId).get();
    final caseMap = caseSnap.data();
    final memberIds =
        List<String>.from(caseMap?['memberIds'] ?? caseMap?['members'] ?? []);

    final actors = await TimelineActor.loadMany(memberIds);
    final partiesLine = _partiesVsLine(memberIds, actors);
    final childrenLine = _childNamesLine(caseMap);
    final rangeLabel =
        '${_dateFmt.format(config._startDay)} — ${_dateFmt.format(config._endDay)}';
    final generatedAt = DateTime.now();

    final messages = config.includeMessages
        ? await CaseMessagingService.fetchMessagesChronological(
            caseId: caseId,
            conversationId: CaseMessagingService.defaultConversationId,
            limit: 500,
            rangeStartInclusive: config._startDay,
            rangeEndInclusive: config._endDay,
          )
        : <Map<String, dynamic>>[];

    final senderIds =
        messages.map((m) => (m['senderId'] ?? '').toString()).toSet();
    final senderActors =
        senderIds.isEmpty ? <String, TimelineActor>{} : await TimelineActor.loadMany(senderIds);

    List<CaseEvent> eventsInRange = [];
    if (config.includeTimeline) {
      final all = await CaseEventService.fetchCaseEvents(caseId);
      eventsInRange = all.where((e) => config._inRange(e.createdAt)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final missedInPeriod = eventsInRange
        .where((e) => e.type.toLowerCase() == 'exchange_missed')
        .length;
    final flaggedInPeriod = messages
        .where((m) =>
            ((m['legalFlag'] ?? '') as Object).toString().trim().isNotEmpty)
        .length;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> documentRows = [];
    Map<String, TimelineActor> docActors = {};
    if (config.includeDocuments) {
      final documentsSnap =
          await CaseDocumentService.documentsCol(caseId).get();
      documentRows = documentsSnap.docs.where((d) {
        final m = d.data();
        if (m['deleted'] == true || m['superseded'] == true) return false;
        final ta = m['uploadedAt'] ?? m['createdAt'];
        if (ta is! Timestamp) return false;
        return config._inRange(ta.toDate());
      }).toList()
        ..sort((a, b) {
          final ta = a.data()['uploadedAt'] ?? a.data()['createdAt'];
          final tb = b.data()['uploadedAt'] ?? b.data()['createdAt'];
          final da = ta is Timestamp
              ? ta.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          final db_ = tb is Timestamp
              ? tb.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          return da.compareTo(db_);
        });
      final uploaderIds = documentRows
          .map((d) => (d.data()['uploadedBy'] ?? '').toString())
          .toSet();
      docActors = uploaderIds.isEmpty
          ? {}
          : await TimelineActor.loadMany(uploaderIds);
    }

    String summaryText = '';
    if (config.includeSummary) {
      final lines = messages
          .map((m) => (m['text'] ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final metrics = StringBuffer()
        ..writeln(
          'Reporting period counts (automated):\n'
          '• Documented custody/timeline rows in period: ${eventsInRange.length}\n'
          '• Missed exchange events (ledger): $missedInPeriod\n'
          '• Messages in period with legal flags recorded: $flaggedInPeriod\n',
        );
      if (lines.isEmpty) {
        summaryText =
            '${metrics.toString().trim()}\n\nNo message text falls within the selected range; narrative summary cannot be generated from transcripts.';
      } else {
        try {
          final ai = await AiService.generateCourtSummary(lines);
          summaryText =
              '${metrics.toString().trim()}\n\nNarrative summary (neutral tone; AI-assisted):\n\n$ai';
        } catch (_) {
          summaryText =
              '${metrics.toString().trim()}\n\n${AiService.insightsUnavailableMessage}';
        }
      }
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(_margin),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Spacer(),
            pw.Text(
              'CASE EXPORT',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 4,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 28),
            pw.Text(
              partiesLine,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 24),
            _coverRow('Child / children', childrenLine),
            pw.SizedBox(height: 10),
            _coverRow('Reporting period', rangeLabel),
            pw.SizedBox(height: 10),
            _coverRow(
              'Generated',
              _dateTimeFmt.format(generatedAt.toLocal()),
            ),
            pw.SizedBox(height: 28),
            pw.Text(
              'Prepared via ParentLedger',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Case ID: $caseId',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
              textAlign: pw.TextAlign.center,
            ),
            pw.Spacer(),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                'Confidential · Attorney work product context — factual system record',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(_margin),
        maxPages: 8000,
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              partiesLine,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
            pw.Text(
              'Period $rangeLabel',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
            ),
            pw.Divider(thickness: 0.5, color: PdfColors.grey600),
          ],
        ),
        footer: (ctx) => _buildFooter(ctx, caseId, generatedAt),
        build: (_) {
          final w = <pw.Widget>[];

          if (config.includeSummary) {
            w.addAll([
              _sectionHeading('SUMMARY'),
              pw.SizedBox(height: 8),
              pw.Text(
                summaryText,
                style: const pw.TextStyle(
                  fontSize: 10,
                  lineSpacing: 1.35,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey500, thickness: 0.5),
              pw.SizedBox(height: 16),
            ]);
          }

          if (config.includeTimeline) {
            w.addAll([
              _sectionHeading('TIMELINE'),
              pw.SizedBox(height: 6),
              pw.Text(
                'Chronological ledger entries (case_events) within the reporting period.',
                style: _meta(),
              ),
              pw.SizedBox(height: 10),
              ..._timelineBlocks(eventsInRange, actors),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey500, thickness: 0.5),
              pw.SizedBox(height: 16),
            ]);
          }

          if (config.includeMessages) {
            w.addAll([
              _sectionHeading('MESSAGES'),
              pw.SizedBox(height: 6),
              pw.Text(
                'Primary conversation — verbatim text as stored. Senders shown as resolved display names when available.',
                style: _meta(),
              ),
              pw.SizedBox(height: 10),
              ..._messageBlocks(messages, senderActors),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey500, thickness: 0.5),
              pw.SizedBox(height: 16),
            ]);
          }

          if (config.includeDocuments) {
            w.addAll([
              _sectionHeading('DOCUMENTS'),
              pw.SizedBox(height: 6),
              pw.Text(
                'Library index for uploads with recorded timestamps in period. Binary files are stored separately; this section lists titles and metadata only.',
                style: _meta(),
              ),
              pw.SizedBox(height: 10),
              _documentsTable(documentRows, docActors),
            ]);
          }

          return w;
        },
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static pw.Widget _coverRow(String k, String v) {
    return pw.Column(
      children: [
        pw.Text(
          k.toUpperCase(),
          style: const pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey700,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          v,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(
    pw.Context ctx,
    String caseId,
    DateTime generatedAt,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey600),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Case ID: $caseId',
                      style:
                          const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                  pw.Text(
                    'Generated ${_dateTimeFmt.format(generatedAt.toLocal())}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                  ),
                  pw.Text(
                    'System-generated record · Prepared via ParentLedger',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                  ),
                ],
              ),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _sectionHeading(String title) => pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.8,
          color: PdfColors.black,
        ),
      );

  static pw.TextStyle _meta() => const pw.TextStyle(
        fontSize: 8.5,
        color: PdfColors.grey800,
        lineSpacing: 1.25,
      );

  static List<pw.Widget> _timelineBlocks(
    List<CaseEvent> events,
    Map<String, TimelineActor> actors,
  ) {
    if (events.isEmpty) {
      return [
        pw.Text(
          'No ledger events recorded in this period.',
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
      final actorName = e.actorName.isNotEmpty
          ? e.actorName
          : (actors[e.actorId]?.fullName ?? e.actorId);
      final desc = e.description.isNotEmpty ? e.description : '(no description)';
      out.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _dateTimeFmt.format(e.createdAt.toLocal()),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.Text(
                'Type: ${e.type}',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
              ),
              pw.Text(
                e.title.isNotEmpty ? e.title : 'Event',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                desc,
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  lineSpacing: 1.3,
                  color: PdfColors.black,
                ),
              ),
              if (actorName.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    'Actor: $actorName',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return out;
  }

  static List<pw.Widget> _messageBlocks(
    List<Map<String, dynamic>> messages,
    Map<String, TimelineActor> senderActors,
  ) {
    if (messages.isEmpty) {
      return [
        pw.Text(
          'No messages in the selected period.',
          style: pw.TextStyle(
            fontSize: 10,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey700,
          ),
        ),
      ];
    }
    final out = <pw.Widget>[];
    for (final m in messages) {
      final sid = (m['senderId'] ?? '').toString();
      final ts = m['createdAt'];
      final dt = ts is Timestamp ? ts.toDate().toLocal() : DateTime.now();
      final iso = ts is Timestamp ? _isoFmt.format(ts.toDate().toUtc()) : '';
      final body = (m['text'] ?? '').toString();
      final flag = m['legalFlag']?.toString();
      final name = sid.isEmpty
          ? 'Unknown'
          : (senderActors[sid]?.fullName ?? sid);
      out.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.35),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _dateTimeFmt.format(dt),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.Text(
                'Sender: $name',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
              ),
              pw.Text(
                'UTC record: $iso',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              if (flag != null && flag.isNotEmpty)
                pw.Text(
                  'Legal flag: $flag',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                body.isEmpty ? '(empty body)' : body,
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  lineSpacing: 1.3,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return out;
  }

  static pw.Widget _documentsTable(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rows,
    Map<String, TimelineActor> uploaders,
  ) {
    if (rows.isEmpty) {
      return pw.Text(
        'No document library entries in the selected period.',
        style: pw.TextStyle(
          fontSize: 10,
          fontStyle: pw.FontStyle.italic,
          color: PdfColors.grey700,
        ),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.4),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cell('Title / file', bold: true),
            _cell('Category', bold: true),
            _cell('Uploaded', bold: true),
          ],
        ),
        ...rows.map((d) {
          final m = d.data();
          final title = (m['title'] ?? m['fileName'] ?? 'Untitled').toString();
          final cat = (m['category'] ?? '—').toString();
          final ta = m['uploadedAt'] ?? m['createdAt'];
          final when = ta is Timestamp
              ? _dateTimeFmt.format(ta.toDate().toLocal())
              : '—';
          final uid = (m['uploadedBy'] ?? '').toString();
          final up = uid.isEmpty
              ? '—'
              : (uploaders[uid]?.fullName ?? uid);
          return pw.TableRow(
            children: [
              _cell('$title\ndocument id: ${d.id}'),
              _cell(cat),
              _cell('$when\n$up'),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          lineSpacing: 1.25,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.black,
        ),
      ),
    );
  }
}
