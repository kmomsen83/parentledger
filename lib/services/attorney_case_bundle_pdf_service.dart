import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/case_document_category.dart';
import '../models/case_event.dart';
import 'ai_service.dart';
import 'case_document_service.dart';
import 'case_event_service.dart';
import 'case_messaging_service.dart';
import 'attorney_pdf_branding_service.dart';
import 'legal_case_report_pdf_service.dart';
import 'timeline_actor_resolver.dart';

/// Court-ready PDF bundle for counsel: AI overview plus verbatim extracts from
/// Firestore (messages, timeline, documents list, ledger events).
class AttorneyCaseBundlePdfService {
  AttorneyCaseBundlePdfService._();

  static final _dateTimeFmt = DateFormat("MMMM d, yyyy · h:mm a");
  static final _isoFmt = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
  static const double _marginPt = 18;

  static Future<Uint8List> buildPdfBytes(String caseId) async {
    await _ensureCaseEvents(caseId);

    final brand = await AttorneyPdfBrandingService.loadForCurrentUser();

    final db = FirebaseFirestore.instance;
    final caseSnap = await db.collection('cases').doc(caseId).get();
    final memberIds = List<String>.from(caseSnap.data()?['memberIds'] ?? []);
    final actors = await TimelineActor.loadMany(memberIds);

    final partyLineStr = _partiesLine(memberIds, actors);

    final messages = await CaseMessagingService.fetchMessagesChronological(
      caseId: caseId,
      conversationId: CaseMessagingService.defaultConversationId,
      limit: 500,
    );

    final senderIds = messages.map((m) => (m['senderId'] ?? '').toString()).toSet();
    final senderActors = await TimelineActor.loadMany(senderIds);

    final aiLines = messages
        .map((m) => (m['text'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();

    String aiSummary;
    if (aiLines.isEmpty) {
      aiSummary =
          'No primary-thread messages were found for this matter. The summary cannot be generated from an empty record.';
    } else {
      try {
        aiSummary = await AiService.generateCourtSummary(aiLines);
      } catch (_) {
        aiSummary = AiService.insightsUnavailableMessage;
      }
    }

    final timelineSnap = await db
        .collection('cases')
        .doc(caseId)
        .collection('timeline')
        .orderBy('timestamp', descending: false)
        .limit(400)
        .get();

    final violationTimelineRows = timelineSnap.docs.where((d) {
      final t = (d.data()['type'] ?? '').toString().toLowerCase();
      return t.contains('miss') ||
          t.contains('violation') ||
          t.contains('flag') ||
          t.contains('risk');
    }).toList();

    final flaggedMessages = messages.where((m) {
      final f = m['legalFlag'];
      return f != null && f.toString().trim().isNotEmpty;
    }).toList();

    final documentsSnap = await CaseDocumentService.documentsCol(caseId).get();
    final documentRows = documentsSnap.docs.where((d) {
      final m = d.data();
      return m['deleted'] != true && m['superseded'] != true;
    }).toList()
      ..sort((a, b) {
        final ta = a.data()['uploadedAt'];
        final tb = b.data()['uploadedAt'];
        final da = ta is Timestamp ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        final db_ = tb is Timestamp ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db_);
      });

    final docUploaderIds =
        documentRows.map((d) => (d.data()['uploadedBy'] ?? '').toString()).toSet();
    final docActors = await TimelineActor.loadMany(docUploaderIds);

    final caseEvents = await CaseEventService.fetchCaseEvents(caseId);

    final generatedAt = DateTime.now();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(_marginPt),
        maxPages: 8000,
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            LegalCaseReportPdfService.buildHeader(
              caseId: caseId,
              generatedAt: generatedAt,
              partiesLine: partyLineStr,
            ),
            if (brand != null) ...[
              pw.SizedBox(height: 8),
              AttorneyPdfBrandingService.buildLetterhead(brand),
            ],
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.red700, width: 0.6),
                color: PdfColors.grey200,
              ),
              child: pw.Text(
                'COUNSEL CASE BUNDLE — WATERMARKED — Informational record only; not legal advice.',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.red900),
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            if (brand != null) AttorneyPdfBrandingService.buildFooter(brand),
            LegalCaseReportPdfService.buildFooter(ctx),
          ],
        ),
        build: (ctx) => [
          _pdfSectionTitle('1. Case summary (AI-assisted)'),
          pw.SizedBox(height: 6),
          pw.Text(
            'The following overview is generated from the message record using the same '
            'court-summary pipeline as in-app tools. It supplements but does not replace the '
            'verbatim message log in Section 2.',
            style: _smallMeta(),
          ),
          pw.SizedBox(height: 8),
          pw.Text(aiSummary, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.35)),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 0.75, color: PdfColors.grey400),
          pw.SizedBox(height: 14),
          _pdfSectionTitle('2. Primary message log (verbatim)'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Exact message text and timestamps as stored in Firestore (primary conversation). '
            'Sender IDs are cryptographic user identifiers; display names are shown when resolved.',
            style: _smallMeta(),
          ),
          pw.SizedBox(height: 10),
          ..._messageBlocks(messages, senderActors),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 0.75, color: PdfColors.grey400),
          pw.SizedBox(height: 14),
          _pdfSectionTitle('3. Violations & flags'),
          pw.SizedBox(height: 8),
          _pdfSectionTitle('3a. Timeline signals (selected types)', level: 12),
          pw.SizedBox(height: 6),
          ..._timelineViolationBlocks(violationTimelineRows),
          pw.SizedBox(height: 12),
          _pdfSectionTitle('3b. Messages with legal flags', level: 12),
          pw.SizedBox(height: 6),
          ..._flaggedMessageBlocks(flaggedMessages, senderActors),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 0.75, color: PdfColors.grey400),
          pw.SizedBox(height: 14),
          _pdfSectionTitle('4. Uploaded documents (library index)'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Titles and metadata from the case document library. Files are stored separately; '
            'this listing identifies records on file.',
            style: _smallMeta(),
          ),
          pw.SizedBox(height: 10),
          _documentsTable(documentRows, docActors),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 0.75, color: PdfColors.grey400),
          pw.SizedBox(height: 14),
          _pdfSectionTitle('5. Case ledger / timeline events'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Chronological entries from the tamper-resistant case event ledger (case_events).',
            style: _smallMeta(),
          ),
          pw.SizedBox(height: 10),
          ..._caseEventBlocks(caseEvents, actors),
        ],
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  static Future<void> _ensureCaseEvents(String caseId) async {
    final list = await CaseEventService.fetchCaseEvents(caseId);
    if (list.isEmpty) {
      await CaseEventService.backfillCaseEvents(caseId);
    }
  }

  static String _partiesLine(
    List<String> memberIds,
    Map<String, TimelineActor> actors,
  ) {
    if (memberIds.isEmpty) return 'Parties: not specified';
    final a = actors[memberIds.first]?.fullName ?? memberIds.first;
    final b = memberIds.length > 1
        ? (actors[memberIds[1]]?.fullName ?? memberIds[1])
        : '—';
    return '$a vs $b';
  }

  static pw.Widget _pdfSectionTitle(String text, {double level = 13}) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: level,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  static pw.TextStyle _smallMeta() => const pw.TextStyle(
        fontSize: 8.5,
        color: PdfColors.grey800,
        lineSpacing: 1.25,
      );

  static List<pw.Widget> _messageBlocks(
    List<Map<String, dynamic>> messages,
    Map<String, TimelineActor> senderActors,
  ) {
    if (messages.isEmpty) {
      return [
        pw.Text(
          'No messages in the primary record.',
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
      final id = (m['messageId'] ?? '').toString();
      final sid = (m['senderId'] ?? '').toString();
      final ts = m['createdAt'];
      final dt = ts is Timestamp ? ts.toDate().toLocal() : DateTime.now();
      final iso =
          ts is Timestamp ? _isoFmt.format(ts.toDate().toUtc()) : '';
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
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Record time (UTC ISO): $iso',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text('Message ID: $id', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Sender UID: $sid', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Sender (resolved): $name', style: const pw.TextStyle(fontSize: 8)),
              if (flag != null && flag.isNotEmpty)
                pw.Text('Legal flag: $flag',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.red900)),
              pw.SizedBox(height: 4),
              pw.Text(
                body.isEmpty ? '(empty body)' : body,
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  lineSpacing: 1.3,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return out;
  }

  static List<pw.Widget> _timelineViolationBlocks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return [
        pw.Text(
          'No qualifying timeline rows in the selected filter.',
          style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic),
        ),
      ];
    }
    final out = <pw.Widget>[];
    for (final d in docs) {
      final m = d.data();
      final ts = m['timestamp'];
      final dt = ts is Timestamp ? ts.toDate().toLocal() : DateTime.now();
      final type = (m['type'] ?? '').toString();
      final metaRaw = m['metadata'];
      final meta = metaRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(metaRaw)
          : metaRaw is Map
              ? Map<String, dynamic>.from(metaRaw)
              : <String, dynamic>{};
      out.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_dateTimeFmt.format(dt),
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('Timeline doc: ${d.id}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Type: $type', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(
                meta.isEmpty ? '(no metadata)' : meta.toString(),
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ],
          ),
        ),
      );
    }
    return out;
  }

  static List<pw.Widget> _flaggedMessageBlocks(
    List<Map<String, dynamic>> messages,
    Map<String, TimelineActor> senderActors,
  ) {
    if (messages.isEmpty) {
      return [
        pw.Text(
          'No messages with a legalFlag field in this pull.',
          style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic),
        ),
      ];
    }
    final out = <pw.Widget>[];
    for (final m in messages) {
      final sid = (m['senderId'] ?? '').toString();
      final ts = m['createdAt'];
      final dt = ts is Timestamp ? ts.toDate().toLocal() : DateTime.now();
      final flag = (m['legalFlag'] ?? '').toString();
      final body = (m['text'] ?? '').toString();
      final name = sid.isEmpty
          ? 'Unknown'
          : (senderActors[sid]?.fullName ?? sid);
      out.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_dateTimeFmt.format(dt),
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('Flag: $flag', style: pw.TextStyle(fontSize: 9, color: PdfColors.red900)),
              pw.Text('Sender: $name ($sid)', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(body, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),
      );
    }
    return out;
  }

  static pw.Widget _documentsTable(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, TimelineActor> uploaders,
  ) {
    if (docs.isEmpty) {
      return pw.Text(
        'No active documents in the library.',
        style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.35),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.8),
        1: pw.FlexColumnWidth(2.4),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: ['Uploaded', 'Title', 'Category', 'Uploader']
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(h,
                      style: pw.TextStyle(
                          fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                ),
              )
              .toList(),
        ),
        ...docs.map((d) {
          final m = d.data();
          final up = m['uploadedAt'];
          final dt = up is Timestamp ? up.toDate().toLocal() : DateTime.now();
          final title = (m['title'] ?? '').toString();
          final catRaw = (m['category'] ?? '').toString();
          final catLabel = () {
            for (final c in CaseDocumentCategory.values) {
              if (c.firestoreValue == catRaw) return c.label;
            }
            return catRaw.isEmpty ? '—' : catRaw;
          }();
          final uid = (m['uploadedBy'] ?? '').toString();
          final uname = uid.isEmpty ? '—' : (uploaders[uid]?.fullName ?? uid);
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(_dateTimeFmt.format(dt), style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(title.isEmpty ? '(untitled)' : title,
                    style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(catLabel, style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(uname, style: const pw.TextStyle(fontSize: 8)),
              ),
            ],
          );
        }),
      ],
    );
  }

  static List<pw.Widget> _caseEventBlocks(
    List<CaseEvent> events,
    Map<String, TimelineActor> actors,
  ) {
    if (events.isEmpty) {
      return [
        pw.Text(
          'No case_events ledger rows returned.',
          style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
        ),
      ];
    }
    final out = <pw.Widget>[];
    for (final e in events) {
      final who = e.actorId.isEmpty
          ? '—'
          : (actors[e.actorId]?.fullName ?? e.actorId);
      out.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _dateTimeFmt.format(e.timestamp.toLocal()),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Type: ${e.type}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Title: ${e.title}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(
                e.description.isNotEmpty ? e.description : '(no description)',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
              pw.Text('Actor: $who', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
      );
    }
    return out;
  }
}
