import 'package:cloud_firestore/cloud_firestore.dart';

import 'case_event.dart';

/// Court-facing view over one `case_events` ledger row + linkage + chain fields.
class UnifiedCaseEvent {
  const UnifiedCaseEvent({
    required this.event,
    required this.relatedIds,
    this.hash,
    this.previousHash,
    this.signature,
    this.timestampMillis,
  });

  final CaseEvent event;
  final List<String> relatedIds;
  final String? hash;
  final String? previousHash;
  final String? signature;
  final int? timestampMillis;

  bool get isEvidenceTagged {
    final tags = event.metadata['tags'];
    if (tags is List && tags.map((e) => e.toString()).contains('evidence')) {
      return true;
    }
    return event.metadata['markedAsEvidence'] == true ||
        event.metadata['important'] == true;
  }

  bool get isFlaggedLegal =>
      event.metadata['legalFlag'] != null &&
      event.metadata['legalFlag'].toString().trim().isNotEmpty;

  factory UnifiedCaseEvent.fromCaseEvent(CaseEvent e) {
    final meta = e.metadata;
    final related = _parseRelatedIds(meta, <String, dynamic>{});
    return UnifiedCaseEvent(
      event: e,
      relatedIds: related,
      timestampMillis: e.createdAt.millisecondsSinceEpoch,
    );
  }

  static UnifiedCaseEvent fromLedgerDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    CaseEvent parsed,
  ) {
    final m = doc.data() ?? <String, dynamic>{};
    final meta = parsed.metadata;
    final data = m['data'];
    final topData =
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final related = _parseRelatedIds(meta, topData);

    final ts = m['timestampMillis'];
    return UnifiedCaseEvent(
      event: parsed,
      relatedIds: related,
      hash: m['hash'] as String?,
      previousHash: m['previousHash'] as String?,
      signature: m['signature'] as String?,
      timestampMillis: ts is int ? ts : int.tryParse('$ts'),
    );
  }

  static List<String> _parseRelatedIds(
    Map<String, dynamic> meta,
    Map<String, dynamic> data,
  ) {
    final out = <String>{};
    void add(dynamic v) {
      if (v is List) {
        for (final e in v) {
          final s = e.toString().trim();
          if (s.isNotEmpty) out.add(s);
        }
      } else if (v is String && v.trim().isNotEmpty) {
        out.add(v.trim());
      }
    }

    add(meta['relatedIds']);
    add(data['relatedIds']);
    add(meta['linkedExchangeId']);
    add(meta['exchangeId']);
    add(meta['expenseId']);
    add(meta['messageId']);
    return out.toList();
  }
}
