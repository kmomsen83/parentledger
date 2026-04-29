import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'case_messaging_service.dart';
import '../models/case_event.dart';
import 'case_event_service.dart';
import 'event_logger_service.dart';

/// Neutral, court-style summaries stored at `cases/{caseId}/legalSummaries/{summaryId}`.
class LegalSummaryService {
  LegalSummaryService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> summariesCol(String caseId) =>
      _db.collection('cases').doc(caseId).collection('legalSummaries');

  /// Builds a non-emotional narrative from the last [messageLimit] messages and stores it.
  /// Optional [rangeStartInclusive] / [rangeEndInclusive] filter the primary thread (date only).
  static Future<String> generateAndStore({
    required String caseId,
    int messageLimit = 100,
    DateTime? rangeStartInclusive,
    DateTime? rangeEndInclusive,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final messages = await CaseMessagingService.fetchMessagesChronological(
      caseId: caseId,
      conversationId: CaseMessagingService.defaultConversationId,
      limit: messageLimit,
      rangeStartInclusive: rangeStartInclusive,
      rangeEndInclusive: rangeEndInclusive,
    );

    if (messages.isEmpty) {
      final docRef = summariesCol(caseId).doc();
      await docRef.set(<String, dynamic>{
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'messageCount': 0,
        'summaryText':
            'No messages were available for this period. No communication actions are recorded.',
        'structured': <String, dynamic>{
          'dateRange': null,
          'actions': <Map<String, dynamic>>[],
          'responsesNoted': 0,
        },
      });
      try {
        await EventLoggerService.logEventForActor(
          caseId: caseId,
          type: CaseEventTypes.statusChange,
          title: 'Legal summary generated',
          description:
              'A neutral communication summary was added to the case file.',
          actorId: user.uid,
          metadata: <String, dynamic>{
            'summaryId': docRef.id,
            'messageCount': 0,
            'summaryKind': 'parent',
          },
        );
      } catch (_) {
        await docRef.delete();
        rethrow;
      }
      return docRef.id;
    }

    final df = DateFormat('yyyy-MM-dd');
    DateTime? first;
    DateTime? last;
    final actions = <Map<String, dynamic>>[];

    for (final m in messages) {
      final ts = m['createdAt'];
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      first ??= dt;
      last = dt ?? last;

      final text = (m['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      final sid = (m['senderId'] ?? '').toString();
      actions.add(<String, dynamic>{
        'date': dt != null ? df.format(dt) : '',
        'senderId': sid,
        // Preserve exact wording for legal integrity in downstream displays/exports.
        'message': text,
        // Legacy key retained for backwards compatibility with previously stored docs.
        'excerpt': text,
      });
    }

    var range =
        first != null && last != null ? '${df.format(first)} to ${df.format(last)}' : null;
    if (rangeStartInclusive != null || rangeEndInclusive != null) {
      final a = rangeStartInclusive != null ? df.format(rangeStartInclusive) : '…';
      final b = rangeEndInclusive != null ? df.format(rangeEndInclusive) : '…';
      range = 'Filter: $a — $b (message dates in range)';
    }

    final buffer = StringBuffer();
    buffer.writeln('COMMUNICATION SUMMARY (NEUTRAL RECORD)');
    if (range != null) {
      buffer.writeln('Period covered: $range.');
    }
    buffer.writeln('Total messages reviewed: ${messages.length}.');
    buffer.writeln();
    buffer.writeln(
      'The following entries summarize dated communications between parties. '
      'Wording is factual; interpretation is reserved for the court.',
    );
    buffer.writeln();
    var i = 1;
    for (final a in actions.take(40)) {
      final msg = (a['message'] ?? a['excerpt'] ?? '').toString();
      buffer.writeln('$i. [${a['date']}] Message recorded (sender ${a['senderId']}).');
      buffer.writeln('   Message: $msg');
      buffer.writeln();
      i++;
    }
    if (actions.length > 40) {
      buffer.writeln(
        'Additional messages (${actions.length - 40}) omitted from body; retained in structured data.',
      );
    }

    final summaryText = buffer.toString();

    final docRef = summariesCol(caseId).doc();
    await docRef.set(<String, dynamic>{
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'messageCount': messages.length,
      'summaryText': summaryText,
      'structured': <String, dynamic>{
        'dateRange': range,
        'rangeFilterStart': rangeStartInclusive?.toIso8601String(),
        'rangeFilterEnd': rangeEndInclusive?.toIso8601String(),
        'actions': actions,
        'responsesNoted': messages.where((m) => m['isRead'] == true).length,
      },
    });

    try {
      await EventLoggerService.logEventForActor(
        caseId: caseId,
        type: CaseEventTypes.statusChange,
        title: 'Legal summary generated',
        description:
            'A neutral communication summary was added to the case file.',
        actorId: user.uid,
        metadata: <String, dynamic>{
          'summaryId': docRef.id,
          'messageCount': messages.length,
          'summaryKind': 'parent',
        },
      );
    } catch (_) {
      await docRef.delete();
      rethrow;
    }

    return docRef.id;
  }

  /// Attorney tool: messages + timeline + violations + neutral pattern notes.
  static Future<String> generateAttorneyCourtSummaryAndStore({
    required String caseId,
    int messageLimit = 100,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final messages = await CaseMessagingService.fetchMessagesChronological(
      caseId: caseId,
      conversationId: CaseMessagingService.defaultConversationId,
      limit: messageLimit,
    );

    final allEvents = await CaseEventService.fetchCaseEvents(caseId);
    final timelineRecent = allEvents.reversed.take(250).toList();
    final violations = allEvents.where((e) {
      final flag = e.metadata['legalFlag']?.toString();
      if (flag != null && flag.isNotEmpty) return true;
      return e.type == CaseEventTypes.statusChange &&
          e.title.toLowerCase().contains('flag');
    }).toList();

    final df = DateFormat('yyyy-MM-dd HH:mm');
    DateTime? first;
    DateTime? last;
    var flaggedMessages = 0;
    final patternTotals = <String, int>{
      'hostileFlagged': 0,
      'nonCompliantFlagged': 0,
    };

    for (final m in messages) {
      final ts = m['createdAt'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        first ??= dt;
        last = dt;
      }
      final flag = m['legalFlag']?.toString();
      if (flag != null) flaggedMessages++;
      if (flag == 'hostile') {
        patternTotals['hostileFlagged'] = patternTotals['hostileFlagged']! + 1;
      } else if (flag == 'non-compliant') {
        patternTotals['nonCompliantFlagged'] =
            patternTotals['nonCompliantFlagged']! + 1;
      }
    }

    final range = first != null && last != null
        ? '${df.format(first)} through ${df.format(last)}'
        : null;

    final buf = StringBuffer();
    buf.writeln('ATTORNEY CASE BRIEF — COMMUNICATION & COMPLIANCE INDEX');
    buf.writeln('(Neutral record — not legal advice.)');
    buf.writeln();
    if (range != null) {
      buf.writeln('Review window: $range.');
    }
    buf.writeln('Messages reviewed: ${messages.length}.');
    buf.writeln('Timeline events pulled: ${timelineRecent.length}.');
    buf.writeln('Violation-flag events: ${violations.length}.');
    buf.writeln('Messages with automated legal flags: $flaggedMessages.');
    buf.writeln();

    buf.writeln('--- TIMELINE (RECENT) ---');
    var ti = 1;
    for (final e in timelineRecent.take(35)) {
      final type = e.type;
      final uid = e.actorId;
      final tss = df.format(e.createdAt.toLocal());
      buf.writeln(
        '$ti. [$tss] $type (actor: $uid)',
      );
      if (e.metadata.isNotEmpty) {
        buf.writeln('   Metadata: ${e.metadata.toString()}');
      }
      ti++;
    }
    if (timelineRecent.length > 35) {
      buf.writeln(
        '… ${timelineRecent.length - 35} additional timeline entries omitted here; retained in structured export.',
      );
    }
    buf.writeln();

    buf.writeln('--- RECORDED VIOLATION FLAGS (CASE EVENTS) ---');
    if (violations.isEmpty) {
      buf.writeln('No flagged case events in this pull.');
    } else {
      var vi = 1;
      for (final e in violations.take(40)) {
        final tss = df.format(e.createdAt.toLocal());
        buf.writeln(
          '$vi. [$tss] ${e.title}: ${e.description} ${e.metadata}',
        );
        vi++;
      }
    }
    buf.writeln();

    buf.writeln('--- COMMUNICATION FLAGS (STORED LEGAL METADATA ON MESSAGES) ---');
    buf.writeln(
      'Counts reflect legalFlag values saved when messages were sent (model-classified).',
    );
    patternTotals.forEach((k, v) {
      buf.writeln('$k: $v');
    });
    buf.writeln();

    buf.writeln('--- MESSAGE INDEX (EXCERPTS) ---');
    var mi = 1;
    for (final m in messages.take(25)) {
      final ts = m['createdAt'];
      String tss = '';
      if (ts is Timestamp) tss = df.format(ts.toDate());
      final sid = (m['senderId'] ?? '').toString();
      final text = (m['text'] ?? '').toString().trim();
      final excerpt =
          text.length > 180 ? '${text.substring(0, 180)}…' : text;
      buf.writeln('$mi. [$tss] sender $sid');
      buf.writeln('   $excerpt');
      mi++;
    }
    if (messages.length > 25) {
      buf.writeln(
        '… ${messages.length - 25} additional messages omitted from body; see structured data.',
      );
    }

    final summaryText = buf.toString();

    final docRef = summariesCol(caseId).doc();
    await docRef.set(<String, dynamic>{
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'summaryKind': 'attorney_brief',
      'messageCount': messages.length,
      'timelineEventCount': timelineRecent.length,
      'violationEventCount': violations.length,
      'summaryText': summaryText,
      'structured': <String, dynamic>{
        'dateRange': range,
        'messagesSampled': messages.length,
        'timeline': timelineRecent
            .take(80)
            .map(
              (e) => <String, dynamic>{
                'type': e.type,
                'actorId': e.actorId,
                'createdAt': Timestamp.fromDate(e.createdAt),
                'title': e.title,
                'description': e.description,
                'metadata': e.metadata,
              },
            )
            .toList(),
        'violations': violations
            .take(60)
            .map(
              (e) => <String, dynamic>{
                'type': e.type,
                'actorId': e.actorId,
                'createdAt': Timestamp.fromDate(e.createdAt),
                'title': e.title,
                'description': e.description,
                'metadata': e.metadata,
              },
            )
            .toList(),
        'communicationPatternCounts': patternTotals,
        'flaggedMessageCount': flaggedMessages,
      },
    });

    try {
      await EventLoggerService.logEventForActor(
        caseId: caseId,
        type: CaseEventTypes.statusChange,
        title: 'Attorney court summary generated',
        description:
            'An attorney brief style summary was added to the case file.',
        actorId: user.uid,
        metadata: <String, dynamic>{
          'summaryId': docRef.id,
          'summaryKind': 'attorney_brief',
          'messageCount': messages.length,
        },
      );
    } catch (_) {
      await docRef.delete();
      rethrow;
    }

    return docRef.id;
  }
}
