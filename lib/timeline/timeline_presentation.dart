import 'package:intl/intl.dart';

import '../models/case_event.dart';
import '../models/timeline_event_model.dart';
import 'case_event_formatter.dart';

/// Display-only transformations shared by Timeline UI and PDF.
/// All strings here derive from [TimelineEventModel] + `case_events` only.
class TimelinePresentation {
  TimelinePresentation._();

  // ---------------------------------------------------------------------------
  // Raw type → legacy UI bucket (matches timeline cards).
  // ---------------------------------------------------------------------------

  static String timelineUiType(TimelineEventModel e) {
    if (e.isMessageLike) return 'message_sent';
    if (e.isExpenseLike) return 'expense_added';
    if (e.isScheduleLike) return 'exchange_scheduled';
    if (e.type == CaseEventTypes.statusChange) {
      final t = e.title.toLowerCase();
      if (t.contains('flag')) return 'violation_flagged';
      if (e.metadata['eventSubtype'] == 'exchange_checkin_completed') {
        return 'exchange_checkin_completed';
      }
      if (t.contains('exchange completed') || t.contains('check-in')) {
        return 'exchange_completed';
      }
      if (t.contains('summary')) return 'summary_generated';
    }
    return 'summary_generated';
  }

  /// Metadata map passed to body builders (preview truncation for messages, etc.).
  static Map<String, dynamic> metaMapFor(TimelineEventModel e) {
    final metaMap = Map<String, dynamic>.from(e.metadata);
    if (e.isMessageLike && e.description.isNotEmpty) {
      final p = e.description.length > 140
          ? '${e.description.substring(0, 140)}…'
          : e.description;
      metaMap['preview'] = p;
    }
    if (e.isExpenseLike) {
      metaMap['description'] =
          metaMap['title'] ?? metaMap['description'] ?? e.description;
    }
    return metaMap;
  }

  static Map<DateTime, List<TimelineEventModel>> groupByDay(
    List<TimelineEventModel> events,
  ) {
    final map = <DateTime, List<TimelineEventModel>>{};
    for (final e in events) {
      final when = e.createdAt;
      final day = DateTime(when.year, when.month, when.day);
      map.putIfAbsent(day, () => []).add(e);
    }
    return map;
  }

  static TimelineDisplayCategory categoryForRawType(String rawType) {
    switch (rawType) {
      case 'message_sent':
      case 'summary_generated':
        return TimelineDisplayCategory.message;
      case 'violation_flagged':
      case 'risk_updated':
        return TimelineDisplayCategory.violation;
      case 'expense_added':
        return TimelineDisplayCategory.expense;
      case 'exchange_scheduled':
      case 'exchange_completed':
      case 'exchange_checkin_completed':
      case 'exchange_missed':
        return TimelineDisplayCategory.exchange;
      default:
        return TimelineDisplayCategory.message;
    }
  }

  static String labelForCategory(TimelineDisplayCategory c) {
    switch (c) {
      case TimelineDisplayCategory.message:
        return 'Message';
      case TimelineDisplayCategory.exchange:
        return 'Exchange';
      case TimelineDisplayCategory.expense:
        return 'Expense';
      case TimelineDisplayCategory.violation:
        return 'Violation';
    }
  }

  static String? headlineForRawType(String rawType) {
    if (rawType == 'exchange_checkin_completed') {
      return 'Exchange Check-In Completed';
    }
    return null;
  }

  static String flagLine(Map<String, dynamic>? meta) {
    final legalFlag = meta?['legalFlag']?.toString();
    if (legalFlag == 'hostile') return 'Hostile language';
    if (legalFlag == 'non-compliant') return 'Non-compliant';
    return '';
  }

  static String bodyForEvent({
    required String rawType,
    required TimelineDisplayCategory category,
    Map<String, dynamic>? meta,
  }) {
    if (meta == null) return '';
    final m = Map<String, dynamic>.from(meta);

    switch (rawType) {
      case 'message_sent':
        final p = m['preview']?.toString() ?? '';
        return p.isEmpty ? '—' : p;
      case 'summary_generated':
        return 'Court summary document generated for the case file.';
      case 'violation_flagged':
        final lf = m['legalFlag']?.toString();
        if (lf != null && lf.isNotEmpty) {
          return 'Message flagged: ${flagLine(m)}';
        }
        return 'Compliance or communication concern logged.';
      case 'risk_updated':
        return 'Case compliance assessment updated.';
      case 'expense_added':
        final amount = m['amount'];
        final desc = m['description']?.toString() ?? '';
        final paid = m['paid'];
        if (amount != null) {
          return '\$$amount${desc.isNotEmpty ? ' · $desc' : ''}'
              '${paid != null ? (paid == true ? ' · Paid' : ' · Unpaid') : ''}';
        }
        return desc.isNotEmpty ? desc : 'Expense record updated.';
      case 'exchange_scheduled':
        final loc = m['locationName']?.toString() ?? '';
        final st = m['scheduledTime'];
        var timeLine = '';
        if (st is String && st.isNotEmpty) {
          final parsed = DateTime.tryParse(st);
          timeLine = parsed != null
              ? DateFormat.yMMMd().add_jm().format(parsed.toLocal())
              : st;
        }
        return [
          if (loc.isNotEmpty) 'Location: $loc',
          if (timeLine.isNotEmpty) 'Scheduled: $timeLine',
        ].join('\n');
      case 'exchange_completed':
        return 'Exchange check-in recorded.';
      case 'exchange_checkin_completed':
        final status = m['verificationStatus']?.toString() ?? '';
        final acc = m['locationAccuracy'];
        final hasPhoto = m['hasPhotoEvidence'] == true;
        final hasNote = m['hasNote'] == true;
        final addr = m['recordedAddress']?.toString() ?? '';
        final timing = m['arrivalTiming']?.toString() ?? '';
        final lines = <String>[];
        if (addr.isNotEmpty) {
          lines.add('Address: $addr');
        }
        if (timing.isNotEmpty && timing != 'on_time') {
          lines.add('Arrival: $timing');
        }
        if (status == 'verified') {
          if (acc != null) {
            lines.add(
              'Location verified (GPS accuracy ±${(acc as num).toStringAsFixed(0)} m)',
            );
          } else {
            lines.add('Location verified');
          }
        } else if (status == 'partial') {
          lines.add(
            'Location recorded — partial verification (outside expected radius or similar)',
          );
        } else {
          lines.add('Location not captured or verification incomplete');
        }
        final ev = <String>[];
        if (hasPhoto) ev.add('Photo evidence');
        if (hasNote) ev.add('Note attached');
        lines.add(
          ev.isEmpty
              ? 'Evidence: none indicated'
              : 'Evidence: ${ev.join(', ')}',
        );
        return lines.join('\n');
      case 'exchange_missed':
        return 'Scheduled exchange was not completed as logged.';
      default:
        final preview = m['preview']?.toString();
        if (preview != null && preview.isNotEmpty) return preview;
        final desc = m['description']?.toString();
        if (desc != null && desc.isNotEmpty) return desc;
        return rawType.replaceAll('_', ' ');
    }
  }

  /// Time line shown on cards — matches timeline UI.
  static String timeLabel({
    required TimelineEventModel e,
    required String rawType,
  }) {
    final headline = headlineForRawType(rawType);
    final when = e.createdAt;
    if (headline != null) {
      return DateFormat.yMMMd().add_jm().format(when.toLocal());
    }
    return DateFormat.jm().format(when.toLocal());
  }

  /// Full date+time for PDF header line (always explicit).
  static String fullDateTime(TimelineEventModel e) {
    return DateFormat.yMMMd().add_jm().format(e.createdAt.toLocal());
  }

  /// `TYPE:` line — same label as the category chip on the timeline card.
  static String typeLineFor(TimelineEventModel e) {
    final raw = timelineUiType(e);
    final cat = categoryForRawType(raw);
    return labelForCategory(cat);
  }

  /// `ACTOR:` / `From:` line — [resolvedName] is from [TimelineActor] when available.
  static String actorLine({
    required TimelineEventModel e,
    required String? resolvedDisplayName,
    required String? resolvedRoleLabel,
  }) {
    if (resolvedDisplayName != null && resolvedDisplayName.isNotEmpty) {
      final role = resolvedRoleLabel ?? 'Participant';
      return '$resolvedDisplayName ($role)';
    }
    if (e.actorName.isNotEmpty) return e.actorName;
    return 'Unknown participant';
  }

  /// Details block — neutral court-style lines plus optional record body.
  static String detailsForPdf(TimelineEventModel e) {
    final raw = timelineUiType(e);
    final formal = CaseEventFormatter.format(e, raw);
    final body = CaseEventFormatter.recordBody(e, raw);
    final buf = StringBuffer()
      ..writeln(formal.title)
      ..writeln(formal.subtitle);
    if (body.isNotEmpty) {
      buf.writeln();
      buf.writeln(body);
    }
    return buf.toString().trim();
  }

  static MessageClassification? classifyMessage({
    required String rawType,
    Map<String, dynamic>? meta,
  }) {
    if (rawType != 'message_sent') {
      return null;
    }
    final legalFlag = meta?['legalFlag']?.toString();

    if (legalFlag == 'hostile') {
      return const MessageClassification(
        tone: MessageTone.hostile,
        label: 'Hostile',
      );
    }
    if (legalFlag == 'non-compliant') {
      return const MessageClassification(
        tone: MessageTone.nonCompliant,
        label: 'Non-compliant',
      );
    }

    return const MessageClassification(
      tone: MessageTone.informational,
      label: 'Informational',
    );
  }

  static TimelineSeverity severityForEvent({
    required String rawType,
    required TimelineDisplayCategory category,
    required MessageClassification? msgClass,
    Map<String, dynamic>? meta,
  }) {
    if (msgClass != null) {
      switch (msgClass.tone) {
        case MessageTone.neutral:
        case MessageTone.informational:
          return TimelineSeverity.subtle;
        case MessageTone.hostile:
        case MessageTone.nonCompliant:
          return TimelineSeverity.warning;
        case MessageTone.escalationRisk:
          return TimelineSeverity.risk;
      }
    }
    if (rawType == 'exchange_checkin_completed') {
      final s = meta?['verificationStatus']?.toString();
      if (s == 'failed') return TimelineSeverity.risk;
      if (s == 'partial') return TimelineSeverity.warning;
      return TimelineSeverity.subtle;
    }
    switch (rawType) {
      case 'violation_flagged':
      case 'exchange_missed':
      case 'risk_updated':
        return TimelineSeverity.risk;
      case 'exchange_completed':
        return TimelineSeverity.subtle;
      case 'expense_added':
        return TimelineSeverity.subtle;
      default:
        if (category == TimelineDisplayCategory.violation) {
          return TimelineSeverity.warning;
        }
        return TimelineSeverity.subtle;
    }
  }
}

enum TimelineDisplayCategory { message, exchange, expense, violation }

enum TimelineSeverity { subtle, warning, risk }

enum MessageTone {
  neutral,
  informational,
  hostile,
  nonCompliant,
  escalationRisk,
}

class MessageClassification {
  const MessageClassification({
    required this.tone,
    required this.label,
  });

  final MessageTone tone;
  final String label;
}
