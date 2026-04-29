import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/case_event.dart';

/// Timeline entries that should appear under **Violations** (recorded case events).
/// Supports legacy `cases/{id}/timeline` docs and unified `caseEvents` rows.
class TimelineViolationFilter {
  TimelineViolationFilter._();

  static Map<String, dynamic> metadataOf(Map<String, dynamic> data) {
    final m = data['metadata'];
    if (m is Map<String, dynamic>) return m;
    if (m is Map) return Map<String, dynamic>.from(m);
    return <String, dynamic>{};
  }

  static bool isViolationEntry(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final meta = metadataOf(data);
    switch (type) {
      case 'violation_flagged':
      case 'exchange_missed':
        return true;
      case 'expense_added':
        final paid = meta['paid'] == true || meta['status'] == 'paid';
        return !paid;
      default:
        return false;
    }
  }

  static bool docIsViolation(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return isViolationEntry(doc.data());
  }

  /// Maps a [CaseEvent] to legacy timeline type strings used by [displayTypeLabel] / [previewLine].
  static String syntheticViolationUiType(CaseEvent e) {
    final lf = e.metadata['legalFlag']?.toString();
    if (lf != null && lf.isNotEmpty) return 'violation_flagged';
    if (e.type == CaseEventTypes.statusChange &&
        e.title.toLowerCase().contains('flag')) {
      return 'violation_flagged';
    }
    if (e.isExpenseLike) {
      final denied =
          e.metadata['status'] == 'denied' || e.type == CaseEventTypes.expenseDenied;
      if (denied) return '';
      final paid = e.metadata['paid'] == true ||
          e.metadata['status'] == 'paid' ||
          e.type == CaseEventTypes.expenseApproved;
      if (!paid) return 'expense_added';
    }
    if (e.metadata['eventSubtype'] == 'exchange_missed') {
      return 'exchange_missed';
    }
    return '';
  }

  static bool caseEventIsViolation(CaseEvent e) {
    return syntheticViolationUiType(e).isNotEmpty;
  }

  /// Short label for list rows (not localized — legal record labels).
  static String displayTypeLabel(String type) {
    switch (type) {
      case 'violation_flagged':
        return 'Communication / compliance flag';
      case 'exchange_missed':
        return 'Missed exchange';
      case 'expense_added':
        return 'Unpaid expense';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  /// Secondary line for list tiles.
  static String previewLine(String type, Map<String, dynamic> meta) {
    switch (type) {
      case 'violation_flagged':
        final lf = meta['legalFlag']?.toString();
        if (lf == 'hostile') return 'Hostile language';
        if (lf == 'non-compliant') return 'Non-compliant';
        if (lf != null && lf.isNotEmpty) return lf;
        return 'Recorded on case timeline';
      case 'exchange_missed':
        return 'Scheduled exchange not completed as logged';
      case 'expense_added':
        final desc = meta['description']?.toString() ?? '';
        final amount = meta['amount'];
        if (amount != null) {
          return '\$$amount${desc.isNotEmpty ? ' · $desc' : ''}';
        }
        return desc.isNotEmpty ? desc : 'Expense pending payment';
      default:
        return '';
    }
  }

  /// Longer body for the detail view.
  static String detailBody(String type, Map<String, dynamic> meta) {
    final preview = previewLine(type, meta);
    final extra = <String>[];
    final mid = meta['messageId']?.toString();
    if (mid != null && mid.isNotEmpty) extra.add('Message ID: $mid');
    final cid = meta['conversationId']?.toString();
    if (cid != null && cid.isNotEmpty) extra.add('Conversation: $cid');
    if (extra.isEmpty) return preview;
    return '$preview\n\n${extra.join('\n')}';
  }
}
