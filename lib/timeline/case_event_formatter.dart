import '../models/case_event.dart';
import '../models/timeline_event_model.dart';

/// Neutral, factual titles and subtitles for court-facing timeline copy.
/// No emotive language; wording matches documented event types only.
class CaseEventFormal {
  const CaseEventFormal({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

/// Maps ledger / timeline rows to official-style headline copy.
class CaseEventFormatter {
  CaseEventFormatter._();

  static CaseEventFormal format(TimelineEventModel e, String rawType) {
    final t = e.type;
    final m = e.metadata;

    if (t == 'invite_accepted') {
      return const CaseEventFormal(
        title: 'Participant joined',
        subtitle: 'A participant accepted an invitation to the case.',
      );
    }

    if (t == CaseEventTypes.expenseApproved || t == 'expense_approved') {
      return const CaseEventFormal(
        title: 'Expense approved',
        subtitle: 'The expense was approved by the other party.',
      );
    }
    if (t == CaseEventTypes.expenseDenied || t == 'expense_denied') {
      return const CaseEventFormal(
        title: 'Expense denied',
        subtitle: 'The expense was marked as denied.',
      );
    }

    if (t == CaseEventTypes.expenseCreated ||
        t == 'expense_created' ||
        t == 'expense') {
      final amt = _amount(m, e);
      return CaseEventFormal(
        title: 'Expense recorded',
        subtitle: '\$${_formatMoney(amt)} expense submitted for review.',
      );
    }

    if (t == CaseEventTypes.checkIn || rawType == 'check_in') {
      final linked = (m['linkedExchangeId'] ?? '').toString().trim();
      return CaseEventFormal(
        title: 'Location check-in',
        subtitle: linked.isNotEmpty
            ? 'Verified GPS presence; linked to a scheduled exchange.'
            : 'Verified GPS presence recorded.',
      );
    }

    if (rawType == 'exchange_checkin_completed' ||
        m['eventSubtype']?.toString() == 'exchange_checkin_completed') {
      return const CaseEventFormal(
        title: 'Arrival recorded',
        subtitle: 'A check-in was recorded at the exchange location.',
      );
    }

    if (_isDocumentUpload(e, t)) {
      return const CaseEventFormal(
        title: 'Document added',
        subtitle: 'A document was uploaded to the case file.',
      );
    }

    if (t == CaseEventTypes.scheduleCreated ||
        t == CaseEventTypes.scheduleUpdated ||
        t == 'schedule_created' ||
        t == 'schedule_updated' ||
        t == 'exchange' ||
        e.isScheduleLike) {
      final et = _exchangeTypeLabel(m);
      final loc = _locationName(m);
      final subtitle = loc.isNotEmpty
          ? 'A $et was scheduled at $loc.'
          : 'A $et was scheduled.';
      return CaseEventFormal(
        title: 'Child exchange scheduled',
        subtitle: subtitle,
      );
    }

    if (t == 'message_sent' ||
        t == CaseEventTypes.message ||
        t == 'message' ||
        e.isMessageLike) {
      return const CaseEventFormal(
        title: 'Message recorded',
        subtitle: 'A message was sent by a participant.',
      );
    }

    return const CaseEventFormal(
      title: 'Activity recorded',
      subtitle: 'An action was logged in the case record.',
    );
  }

  /// Substantive text shown below the neutral subtitle (e.g. message body, file name).
  static String recordBody(TimelineEventModel e, String rawType) {
    final m = e.metadata;
    final t = e.type;

    if (t == 'message_sent' ||
        t == CaseEventTypes.message ||
        t == 'message' ||
        e.isMessageLike) {
      final text = e.description.trim();
      if (text.isNotEmpty) {
        return text;
      }
      return (m['preview'] ?? '').toString().trim();
    }

    if (t == CaseEventTypes.expenseCreated ||
        t == 'expense_created' ||
        t == 'expense') {
      return (m['title'] ?? m['description'] ?? '').toString().trim();
    }

    if (_isDocumentUpload(e, t)) {
      return (m['fileName'] ?? e.description).toString().trim();
    }

    if (t == CaseEventTypes.checkIn || rawType == 'check_in') {
      final addr = (m['address'] ?? '').toString().trim();
      if (addr.isNotEmpty) return addr;
      final lat = m['lat'];
      final lng = m['lng'];
      if (lat != null && lng != null) {
        return '${lat.toString()}, ${lng.toString()}';
      }
      return '';
    }

    if (rawType == 'exchange_checkin_completed' ||
        m['eventSubtype']?.toString() == 'exchange_checkin_completed') {
      final addr = (m['recordedAddress'] ?? '').toString().trim();
      return addr;
    }

    return '';
  }

  static bool _isDocumentUpload(TimelineEventModel e, String t) {
    if (t != CaseEventTypes.statusChange && t != 'status_change') {
      return false;
    }
    if (mHasDocument(m: e.metadata)) {
      return true;
    }
    final lower = e.title.toLowerCase();
    return lower.contains('document') && lower.contains('upload');
  }

  static bool mHasDocument({required Map<String, dynamic> m}) =>
      m.containsKey('documentId');

  static String _exchangeTypeLabel(Map<String, dynamic> m) {
    final v = (m['exchangeType'] ?? m['type'] ?? '').toString().trim();
    if (v.isEmpty) {
      return 'child exchange';
    }
    return v;
  }

  static String _locationName(Map<String, dynamic> m) {
    return (m['locationName'] ?? m['location'] ?? '').toString().trim();
  }

  static double _amount(Map<String, dynamic> m, TimelineEventModel e) {
    final a = m['amount'];
    if (a is num) {
      return a.toDouble();
    }
    return double.tryParse(a?.toString() ?? '') ??
        double.tryParse(e.description) ??
        0.0;
  }

  static String _formatMoney(double v) {
    return v.toStringAsFixed(2);
  }
}
