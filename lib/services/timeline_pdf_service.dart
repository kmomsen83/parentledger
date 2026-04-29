import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/timeline_event_model.dart';
import '../timeline/timeline_presentation.dart';
import 'timeline_actor_resolver.dart';

/// Printable timeline — layout mirrors grouped timeline UI (date headers + cards).
class TimelinePdfService {
  TimelinePdfService._();

  static final _dayHeaderFmt = DateFormat('MMMM d, yyyy');

  /// [events] must be newest-first (same order as [CaseEventService.watchTimelineModels]).
  static Future<Uint8List> buildPdfBytes({
    required String caseId,
    required String caseTitle,
    required List<TimelineEventModel> eventsNewestFirst,
    required Map<String, TimelineActor> actors,
    required bool integrityVerified,
    DateTime? generatedAt,
  }) async {
    final gen = generatedAt ?? DateTime.now();
    final genLabel = DateFormat.yMMMd().add_jm().format(gen.toLocal());

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Official Case Record',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            caseTitle,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Case ID: $caseId',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Generated: $genLabel',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 0.8, color: PdfColors.grey400),
          pw.SizedBox(height: 14),
          if (eventsNewestFirst.isEmpty)
            pw.Text(
              'No recorded activity for this case.',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            )
          else ..._sectionsForGrouped(eventsNewestFirst, actors),
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 0.6, color: PdfColors.grey400),
          pw.SizedBox(height: 10),
          if (integrityVerified) ...[
            pw.Text(
              'Verified timeline record. No alterations detected.',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.SizedBox(height: 8),
          ],
          pw.Text(
            'ParentLedger — neutral system-generated copy of case timeline events.',
            style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.4),
          ),
        ],
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  static List<pw.Widget> _sectionsForGrouped(
    List<TimelineEventModel> eventsNewestFirst,
    Map<String, TimelineActor> actors,
  ) {
    final grouped = TimelinePresentation.groupByDay(eventsNewestFirst);
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final out = <pw.Widget>[];

    for (final day in days) {
      final dayEvents = grouped[day]!;
      out.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10, top: 4),
          child: pw.Text(
            '--- ${_dayHeaderFmt.format(day)} ---',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );

      for (var i = 0; i < dayEvents.length; i++) {
        final e = dayEvents[i];
        out.add(_eventBlock(e, actors));
        if (i < dayEvents.length - 1) {
          out.add(pw.SizedBox(height: 12));
          out.add(pw.Divider(color: PdfColors.grey300));
          out.add(pw.SizedBox(height: 12));
        }
      }
      out.add(pw.SizedBox(height: 18));
    }

    return out;
  }

  static pw.Widget _eventBlock(
    TimelineEventModel e,
    Map<String, TimelineActor> actors,
  ) {
    final actor = e.actorId.isNotEmpty ? actors[e.actorId] : null;
    final actorText = TimelinePresentation.actorLine(
      e: e,
      resolvedDisplayName: actor?.fullName,
      resolvedRoleLabel: actor?.roleLabel,
    );

    final typeDisplay = TimelinePresentation.typeLineFor(e);
    final when = TimelinePresentation.fullDateTime(e);
    final details = TimelinePresentation.detailsForPdf(e);

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            when,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'TYPE: $typeDisplay',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'ACTOR: $actorText',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'DETAILS:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            details,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.35),
          ),
        ],
      ),
    );
  }
}
