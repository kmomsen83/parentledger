import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';

/// Export-ready view of a stored court communication summary.
class LegalSummaryDetailScreen extends StatelessWidget {
  const LegalSummaryDetailScreen({
    super.key,
    required this.caseId,
    required this.summaryId,
  });

  final String caseId;
  final String summaryId;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('cases')
        .doc(caseId)
        .collection('legalSummaries')
        .doc(summaryId);

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('courtCommunicationSummary')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Copy full text',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              final snap = await ref.get();
              final text = (snap.data()?['summaryText'] ?? '').toString();
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tTone('summaryCopiedToClipboard'))),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load summary: ${snap.error}',
                  style: PLDesign.body.copyWith(color: PLDesign.danger),
                ),
              ),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() ?? {};
          final text = (data['summaryText'] ?? '').toString();
          final created = data['createdAt'];
          DateTime? at;
          if (created is Timestamp) at = created.toDate();
          final df = DateFormat('MMM d, yyyy · HH:mm');
          final entryDateFmt = DateFormat('MMMM d, yyyy');
          final meta = data['structured'];
          final messageCount = data['messageCount'];
          final kind = (data['summaryKind'] ?? '').toString();
          final isAttorneyBrief = kind == 'attorney_brief';
          final generatedAt = at ?? DateTime.now();

          final actions = meta is Map && meta['actions'] is List
              ? List<Map<String, dynamic>>.from(
                  (meta['actions'] as List).map(
                    (e) => Map<String, dynamic>.from(
                      e is Map ? Map<dynamic, dynamic>.from(e) : <String, dynamic>{},
                    ),
                  ),
                )
              : <Map<String, dynamic>>[];

          return Container(
            decoration: const BoxDecoration(gradient: PLDesign.pageGradient),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: PLDesign.elevatedCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAttorneyBrief
                              ? 'Attorney brief (messages + timeline + flags)'
                              : 'Neutral record',
                          style: PLDesign.caption.copyWith(
                            color: PLDesign.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (at != null)
                          Text(
                            'Generated ${df.format(at)}',
                            style: PLDesign.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (messageCount != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Messages reviewed: $messageCount',
                              style: PLDesign.caption,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (actions.isNotEmpty)
                    ...actions.map((entry) {
                      final dateText = (entry['date'] ?? '').toString().trim();
                      final senderId = (entry['senderId'] ?? '').toString().trim();
                      final message =
                          (entry['message'] ?? entry['excerpt'] ?? '').toString();
                      DateTime? parsedDate;
                      if (dateText.isNotEmpty) {
                        parsedDate = DateTime.tryParse(dateText);
                      }
                      final displayDate = parsedDate != null
                          ? entryDateFmt.format(parsedDate.toLocal())
                          : (dateText.isEmpty ? 'Date pending' : dateText);
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: PLDesign.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PLDesign.border),
                          boxShadow: PLDesign.softShadow,
                        ),
                        child: SelectableText(
                          '$displayDate\n'
                          'Sender ID: ${senderId.isEmpty ? 'unknown' : senderId}\n\n'
                          'Message:\n'
                          '"$message"',
                          style: PLDesign.body.copyWith(
                            height: 1.55,
                            fontSize: 14,
                          ),
                        ),
                      );
                    })
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: PLDesign.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PLDesign.border),
                        boxShadow: PLDesign.softShadow,
                      ),
                      child: SelectableText(
                        text.isEmpty
                            ? 'No summary text was stored for this document.'
                            : text,
                        style: PLDesign.body.copyWith(
                          height: 1.55,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Divider(color: PLDesign.border.withValues(alpha: 0.8)),
                  const SizedBox(height: 10),
                  SelectableText(
                    'Generated by ParentLedger\n'
                    'Case ID: $caseId\n'
                    'Report generated: ${df.format(generatedAt)}\n\n'
                    'This document is a neutral, system-generated summary of recorded communications.\n'
                    'No interpretation or modification has been applied.',
                    style: PLDesign.caption.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
