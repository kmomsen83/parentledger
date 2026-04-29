import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/negotiation_proposal.dart';
import 'timeline_actor_resolver.dart';

/// Printable proposal agreement record for filings and counsel packets.
class ProposalPdfService {
  ProposalPdfService._();

  static Future<Uint8List> buildNegotiationRecordPdf({
    required NegotiationProposal proposal,
    required String caseTitle,
    List<ProposalMessage>? messagesOldestFirst,
    DateTime? generatedAt,
  }) async {
    final gen = generatedAt ?? DateTime.now();
    final genLabel = DateFormat.yMMMd().add_jm().format(gen.toLocal());
    final df = DateFormat.yMMMd().add_jm();

    final creator = await TimelineActor.load(proposal.createdBy);
    String? accepterName;
    if ((proposal.acceptedBy ?? '').isNotEmpty) {
      accepterName = (await TimelineActor.load(proposal.acceptedBy!)).fullName;
    }

    final msgSenders = <String>{
      ...?messagesOldestFirst?.map((m) => m.senderId),
    };
    final msgActors =
        msgSenders.isEmpty ? <String, TimelineActor>{} : await TimelineActor.loadMany(msgSenders);

    String fmtTs(DateTime? t) =>
        t == null ? '—' : df.format(t.toLocal());

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'ParentLedger — proposal record',
            style: pw.TextStyle(
              fontSize: 18,
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
          pw.Text('Generated: $genLabel', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 0.6, color: PdfColors.grey400),
          pw.SizedBox(height: 12),
          _kv('Title', proposal.title),
          _kv('Child', proposal.childName),
          _kv('Category', proposal.kind),
          _kv('Status', proposal.status),
          _kv('Revision', proposal.proposedRevision.toString()),
          _kv('Created', fmtTs(proposal.createdAt)),
          _kv('Logged by', creator.fullName),
          if (proposal.negotiatingStartedAt != null)
            _kv('Negotiation opened', fmtTs(proposal.negotiatingStartedAt)),
          if (proposal.acceptedAt != null) ...[
            _kv('Accepted at', fmtTs(proposal.acceptedAt)),
            if (accepterName != null) _kv('Accepted by', accepterName),
          ],
          if (proposal.rejectedAt != null)
            _kv('Rejected at', fmtTs(proposal.rejectedAt)),
          if (proposal.finalizedAt != null)
            _kv('Record finalized', fmtTs(proposal.finalizedAt)),
          pw.SizedBox(height: 14),
          pw.Text(
            'Prior terms',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          ..._mapLines(proposal.originalData),
          pw.SizedBox(height: 12),
          pw.Text(
            'Agreed / final proposed terms',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          ..._mapLines(proposal.proposedData),
          if (messagesOldestFirst != null && messagesOldestFirst.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Discussion (chronological)',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            for (final m in messagesOldestFirst)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${df.format(m.createdAt.toLocal())} — ${msgActors[m.senderId]?.fullName ?? 'Participant'}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(m.text, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            'This document reflects application state at export time. Chain-of-custody events remain in the official case ledger.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  static pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              k,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  static List<pw.Widget> _mapLines(Map<String, dynamic> m) {
    if (m.isEmpty) {
      return [
        pw.Text('—', style: const pw.TextStyle(fontSize: 9)),
      ];
    }
    final keys = m.keys.toList()..sort();
    return keys
        .map(
          (k) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              '$k: ${_formatVal(m[k])}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        )
        .toList();
  }

  static String _formatVal(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    return s.isEmpty ? '—' : s;
  }
}
