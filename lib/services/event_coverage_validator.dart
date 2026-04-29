import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/case_event.dart';

/// Debug-only helper: compares authoritative Firestore activity rows against
/// unified [caseEvents] so missing audit logs surface during development.
///
/// **Never used in release** — [validateRecentActivity] is a no-op when
/// [kDebugMode] is false, and the UI entry point should be guarded the same way.
class EventCoverageValidator {
  EventCoverageValidator._();

  /// Canonical list of user-facing actions the product should log to [caseEvents].
  static const List<String> expectedEventTriggers = <String>[
    'message_sent',
    'expense_created',
    'expense_approved',
    'expense_denied',
    'schedule_created',
    'schedule_updated',
    'exchange_checkin',
    'document_uploaded',
    'invite_accepted',
  ];

  static final _db = FirebaseFirestore.instance;

  /// Default lookback for activity and [caseEvents] rows (client-filtered).
  static const Duration defaultRecentWindow = Duration(days: 90);

  /// Cross-checks recent subcollections against [caseEvents] for [caseId].
  ///
  /// Logs grouped totals and each mismatch via [debugPrint]. Returns counts for tests/UI.
  static Future<EventCoverageReport> validateRecentActivity(
    String caseId, {
    Duration recentWindow = defaultRecentWindow,
  }) async {
    if (!kDebugMode) {
      return EventCoverageReport.skipped(caseId);
    }

    final cutoff = DateTime.now().subtract(recentWindow);
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════════════════');
    debugPrint('║ Case Event Coverage Validator (debug only)');
    debugPrint('╠══════════════════════════════════════════════════════════════');
    debugPrint('║ caseId: $caseId');
    debugPrint('║ window: $recentWindow (since ${cutoff.toIso8601String()})');
    debugPrint('╚══════════════════════════════════════════════════════════════');

    final events = await _loadCaseEvents(caseId, cutoff);
    var actionsChecked = 0;
    var mismatches = 0;
    final mismatchLines = <String>[];

    void expect(
      String logicalType,
      String refLabel,
      bool satisfied,
    ) {
      actionsChecked++;
      if (!satisfied) {
        mismatches++;
        final line =
            'MISSING EVENT: $logicalType for $refLabel';
        mismatchLines.add(line);
        debugPrint('⚠ $line');
      }
    }

    // --- Messages → message (CaseEventTypes.message) ---
    final conversations =
        await _db.collection('cases').doc(caseId).collection('conversations').get();
    var messagesInWindow = 0;
    for (final conv in conversations.docs) {
      final msgs = await _db
          .collection('cases')
          .doc(caseId)
          .collection('conversations')
          .doc(conv.id)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();

      for (final m in msgs.docs) {
        final data = m.data();
        final ts = _readTime(data['createdAt']);
        if (ts != null && ts.isBefore(cutoff)) continue;
        messagesInWindow++;
        final messageId = m.id;
        expect(
          'message_sent',
          'messageId $messageId (conversation ${conv.id})',
          _hasMessageEvent(events, messageId),
        );
      }
    }

    // --- Expenses ---
    final expenseSnap =
        await _db.collection('cases').doc(caseId).collection('expenses').get();
    var expensesInWindow = 0;
    for (final doc in expenseSnap.docs) {
      final data = doc.data();
      final ts = _readTime(data['createdAt']);
      if (ts != null && ts.isBefore(cutoff)) continue;
      expensesInWindow++;
      final expenseId = doc.id;

      expect(
        'expense_created',
        'expenseId $expenseId',
        _hasExpenseCreatedEvent(events, expenseId),
      );

      final status =
          (data['status'] ?? (data['paid'] == true ? 'paid' : 'unpaid'))
              .toString()
              .toLowerCase();

      if (status == 'paid') {
        final coveredByCreation = _expenseCreatedShowsPaid(events, expenseId);
        expect(
          'expense_approved',
          'expenseId $expenseId',
          _hasExpenseApprovedEvent(events, expenseId) || coveredByCreation,
        );
      } else if (status == 'denied') {
        expect(
          'expense_denied',
          'expenseId $expenseId',
          _hasExpenseDeniedEvent(events, expenseId),
        );
      }
    }

    // --- Exchanges (schedules) → schedule_created ---
    final exchSnap =
        await _db.collection('cases').doc(caseId).collection('exchanges').get();
    var exchangesInWindow = 0;
    for (final doc in exchSnap.docs) {
      final data = doc.data();
      final ts = _readTime(data['createdAt'] ?? data['scheduledTime']);
      if (ts != null && ts.isBefore(cutoff)) continue;
      exchangesInWindow++;
      final exchangeId = doc.id;
      expect(
        'schedule_created',
        'exchangeId $exchangeId',
        _hasScheduleCreatedEvent(events, exchangeId),
      );
    }

    // --- Exchange check-ins → status_change + eventSubtype / checkInId ---
    final checkInsSnap = await _db
        .collection('cases')
        .doc(caseId)
        .collection('exchange_checkins')
        .get();
    var checkInsInWindow = 0;
    for (final doc in checkInsSnap.docs) {
      final data = doc.data();
      final ts = _readTime(data['createdAt']);
      if (ts != null && ts.isBefore(cutoff)) continue;
      checkInsInWindow++;
      final checkInId = doc.id;
      expect(
        'exchange_checkin',
        'checkInId $checkInId',
        _hasExchangeCheckinEvent(events, checkInId),
      );
    }

    // --- Documents ---
    final docsSnap =
        await _db.collection('cases').doc(caseId).collection('documents').get();
    var documentsInWindow = 0;
    for (final doc in docsSnap.docs) {
      final data = doc.data();
      final ts = _readTime(data['uploadedAt']);
      if (ts != null && ts.isBefore(cutoff)) continue;
      documentsInWindow++;
      final documentId = doc.id;
      expect(
        'document_uploaded',
        'documentId $documentId',
        _hasDocumentUploadedEvent(events, documentId),
      );
    }

    // --- Accepted invites (caseInvites) → Invite accepted caseEvent ---
    final invitesSnap = await _db
        .collection('caseInvites')
        .where('caseId', isEqualTo: caseId)
        .limit(200)
        .get();
    var acceptedInvitesInWindow = 0;
    for (final doc in invitesSnap.docs) {
      final data = doc.data();
      final st = (data['status'] ?? '').toString().toLowerCase();
      if (st != 'accepted') continue;
      final ts = _readTime(data['acceptedAt'] ?? data['updatedAt'] ?? data['createdAt']);
      if (ts != null && ts.isBefore(cutoff)) continue;
      acceptedInvitesInWindow++;
      final inviteId = doc.id;
      expect(
        'invite_accepted',
        'inviteId $inviteId',
        _hasInviteAcceptedEvent(events, inviteId),
      );
    }

    // --- Report: schedule_updated is not derived from current exchange schema (no updatedAt) ---
    debugPrint('');
    debugPrint('── Activity scanned (in window) ──');
    debugPrint(
      '  messages: $messagesInWindow | expenses: $expensesInWindow | '
      'exchanges: $exchangesInWindow | check-ins: $checkInsInWindow | '
      'documents: $documentsInWindow | accepted invites: $acceptedInvitesInWindow',
    );
    debugPrint(
      '  note: schedule_updated is listed in expectedEventTriggers but is not '
      'validated here (exchanges have no updatedAt; cannot infer updates vs creates).',
    );

    final eventsInWindow = events.length;
    debugPrint('');
    debugPrint('── Summary ──');
    debugPrint('  total actions checked: $actionsChecked');
    debugPrint('  caseEvents in window:  $eventsInWindow');
    debugPrint('  mismatches:            $mismatches');
    debugPrint('╚═ (end Case Event Coverage Validator)');

    return EventCoverageReport(
      caseId: caseId,
      recentWindow: recentWindow,
      actionsChecked: actionsChecked,
      caseEventsInWindow: eventsInWindow,
      mismatches: mismatches,
      mismatchDetails: List<String>.unmodifiable(mismatchLines),
    );
  }

  static Future<List<CaseEvent>> _loadCaseEvents(
    String caseId,
    DateTime cutoff,
  ) async {
    final snap = await _db
        .collection('case_events')
        .where('caseId', isEqualTo: caseId)
        .limit(3000)
        .get();
    return snap
        .docs
        .map(CaseEvent.fromDoc)
        .where((e) => !e.createdAt.isBefore(cutoff))
        .toList();
  }

  static DateTime? _readTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }

  static bool _hasMessageEvent(List<CaseEvent> events, String messageId) {
    for (final e in events) {
      if (e.isMessageLike && _str(e.metadata['messageId']) == messageId) {
        return true;
      }
    }
    return false;
  }

  static bool _hasExpenseCreatedEvent(List<CaseEvent> events, String expenseId) {
    for (final e in events) {
      if ((e.type == CaseEventTypes.expenseCreated || e.type == 'expense') &&
          _str(e.metadata['expenseId']) == expenseId) {
        return true;
      }
    }
    return false;
  }

  static bool _expenseCreatedShowsPaid(List<CaseEvent> events, String expenseId) {
    for (final e in events) {
      if (e.type == CaseEventTypes.expenseCreated &&
          _str(e.metadata['expenseId']) == expenseId) {
        final st = _str(e.metadata['status']).toLowerCase();
        return st == 'paid';
      }
    }
    return false;
  }

  static bool _hasExpenseApprovedEvent(List<CaseEvent> events, String expenseId) {
    for (final e in events) {
      if (e.type == CaseEventTypes.expenseApproved &&
          _str(e.metadata['expenseId']) == expenseId) {
        return true;
      }
    }
    return false;
  }

  static bool _hasExpenseDeniedEvent(List<CaseEvent> events, String expenseId) {
    for (final e in events) {
      if (e.type == CaseEventTypes.expenseDenied &&
          _str(e.metadata['expenseId']) == expenseId) {
        return true;
      }
    }
    return false;
  }

  static bool _hasScheduleCreatedEvent(List<CaseEvent> events, String exchangeId) {
    for (final e in events) {
      if (e.isScheduleLike &&
          (e.type == CaseEventTypes.scheduleCreated || e.type == 'exchange') &&
          (_str(e.metadata['exchangeId']) == exchangeId ||
              _str(e.metadata['scheduleId']) == exchangeId)) {
        return true;
      }
    }
    return false;
  }

  static bool _hasExchangeCheckinEvent(List<CaseEvent> events, String checkInId) {
    for (final e in events) {
      if (_str(e.metadata['checkInId']) == checkInId) return true;
    }
    return false;
  }

  static bool _hasDocumentUploadedEvent(List<CaseEvent> events, String documentId) {
    for (final e in events) {
      if (e.type == 'document' && _str(e.metadata['documentId']) == documentId) {
        return true;
      }
      if (e.type == CaseEventTypes.statusChange &&
          e.title.toLowerCase().contains('document') &&
          _str(e.metadata['documentId']) == documentId) {
        return true;
      }
    }
    return false;
  }

  static bool _hasInviteAcceptedEvent(List<CaseEvent> events, String inviteId) {
    for (final e in events) {
      if (e.type == CaseEventTypes.statusChange &&
          e.title.toLowerCase().contains('invite') &&
          _str(e.metadata['inviteId']) == inviteId) {
        return true;
      }
    }
    return false;
  }

  static String _str(dynamic v) => (v ?? '').toString();
}

/// Result of a coverage run (useful for UI snackbars in debug).
class EventCoverageReport {
  const EventCoverageReport({
    required this.caseId,
    required this.recentWindow,
    required this.actionsChecked,
    required this.caseEventsInWindow,
    required this.mismatches,
    required this.mismatchDetails,
    this.skipped = false,
  });

  factory EventCoverageReport.skipped(String caseId) => EventCoverageReport(
        caseId: caseId,
        recentWindow: Duration.zero,
        actionsChecked: 0,
        caseEventsInWindow: 0,
        mismatches: 0,
        mismatchDetails: const <String>[],
        skipped: true,
      );

  final String caseId;
  final Duration recentWindow;
  final int actionsChecked;
  final int caseEventsInWindow;
  final int mismatches;
  final List<String> mismatchDetails;
  final bool skipped;
}
