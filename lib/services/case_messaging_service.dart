import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ai_service.dart';
import '../models/case_event.dart';
import 'event_logger_service.dart';
import 'case_participant_service.dart';
import 'case_paths.dart';
import 'case_thread_catalog.dart';
import 'crashlytics_service.dart';
import 'custody_risk_insights_service.dart';
import 'notification_service.dart';
import 'message_text_formatter.dart';
import '../models/user_role.dart';
import 'user_role_service.dart';

/// Production messaging under:
/// `cases/{caseId}/conversations/{conversationId}/messages/{messageId}`
class CaseMessagingService {
  CaseMessagingService._();

  static final _db = FirebaseFirestore.instance;

  /// Default thread per case (extend to list UI later).
  static const String defaultConversationId = CasePaths.defaultConversationId;

  static DocumentReference<Map<String, dynamic>> conversationRef(
    String caseId,
    String conversationId,
  ) =>
      _db.collection('cases').doc(caseId).collection('conversations').doc(conversationId);

  /// Ensures standard threads ([CaseThreadCatalog.orderedThreadIds]) exist, syncs
  /// [memberIds], and never overwrites an existing [lastMessagePreview].
  static Future<void> ensureCaseThreads(String caseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final role = await UserRoleService.currentRole();
    if (role == UserRole.attorney) {
      return;
    }

    final caseSnap = await _db.collection('cases').doc(caseId).get();
    final members = List<String>.from(caseSnap.data()?['memberIds'] ?? <String>[]);
    final uniq = <String>{...members, user.uid}.toList();

    for (final id in CaseThreadCatalog.orderedThreadIds) {
      final convRef = conversationRef(caseId, id);
      final snap = await convRef.get();
      final exists = snap.exists;
      final prev = snap.data();
      final prevTitle = (prev?['title'] ?? '').toString().trim();

      if (!exists) {
        await convRef.set(<String, dynamic>{
          'caseId': caseId,
          'title': CaseThreadCatalog.defaultTitleForId(id),
          'memberIds': uniq,
          'lastMessagePreview': '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await convRef.set(
          <String, dynamic>{
            'caseId': caseId,
            'memberIds': uniq,
            if (prevTitle.isEmpty || prevTitle == 'Case discussion')
              'title': CaseThreadCatalog.defaultTitleForId(id),
          },
          SetOptions(merge: true),
        );
      }
    }

    for (final uid in uniq) {
      await CaseParticipantService.ensureParticipant(
        caseId: caseId,
        userId: uid,
      );
    }
  }

  /// Backward-compatible alias — seeds all standard threads.
  static Future<void> ensureDefaultConversation(String caseId) =>
      ensureCaseThreads(caseId);

  static CollectionReference<Map<String, dynamic>> messagesRef(
    String caseId,
    String conversationId,
  ) =>
      conversationRef(caseId, conversationId).collection('messages');

  /// Real-time feed, newest first (UI typically uses reverse list).
  /// IMPORTANT: Do not listen manually and use the same stream in a [StreamBuilder]. One
  /// [StreamBuilder] (or separate [watchMessages] calls = separate native subscriptions) per design.
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
    String caseId,
    String conversationId,
  ) =>
      messagesRef(caseId, conversationId)
          .orderBy('createdAt', descending: true)
          .snapshots();

  static String? _legalFlagFromTone(Map<String, dynamic> tone) {
    final v = tone['legalFlag'];
    if (v == null) return null;
    final s = v.toString().trim().toLowerCase();
    if (s == 'hostile') return 'hostile';
    if (s == 'non-compliant' || s == 'noncompliant') return 'non-compliant';
    return null;
  }

  /// Immutable send — [createdAt] is the only server time field on create.
  ///
  /// When [toneClassification] is provided (e.g. after a pre-send UI check), it is
  /// used for [legalFlag] and the model is not called again for this send.
  static Future<void> sendTextMessage({
    required String caseId,
    required String conversationId,
    required String text,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? toneClassification,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    if (await UserRoleService.currentRole() == UserRole.attorney) {
      throw StateError('Attorney accounts have read-only access to messages.');
    }

    final formatted = MessageTextFormatter.formatProfessionalMessage(text);
    if (formatted.isEmpty) throw StateError('Message is empty');

    final caseSnap = await _db.collection('cases').doc(caseId).get();
    final members = List<String>.from(caseSnap.data()?['memberIds'] ?? []);

    final tone = toneClassification ??
        await AiService.classifyCoParentMessage(formatted);
    final legalFlag = _legalFlagFromTone(tone);
    final msgRef = messagesRef(caseId, conversationId).doc();

    final preview = formatted.length > 140
        ? '${formatted.substring(0, 140)}…'
        : formatted;

    await msgRef.set(<String, dynamic>{
      'text': formatted,
      'senderId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'isRead': false,
      'type': 'text',
      'attachments': attachments ?? <Map<String, dynamic>>[],
      'immutable': true,
      'tags': <String>[],
      'important': false,
      'markedAsEvidence': false,
      if (legalFlag != null) 'legalFlag': legalFlag,
    });

    try {
      await EventLoggerService.logEventForActor(
        caseId: caseId,
        type: CaseEventTypes.message,
        title: legalFlag != null ? 'Message sent (flagged)' : 'Message sent',
        description: formatted,
        actorId: user.uid,
        metadata: <String, dynamic>{
          'messageId': msgRef.id,
          'conversationId': conversationId,
          'preview': formatted.length > 50
              ? formatted.substring(0, 50)
              : formatted,
          if (legalFlag != null) 'legalFlag': legalFlag,
          if (legalFlag != null) 'communicationFlagged': true,
        },
      );
    } catch (e, st) {
      await msgRef.delete();
      await CrashlyticsService.recordError(
        e,
        st,
        reason: 'case_event ledger failed after message write',
      );
      rethrow;
    }

    await conversationRef(caseId, conversationId).set(
      <String, dynamic>{
        'caseId': caseId,
        'title': CaseThreadCatalog.defaultTitleForId(conversationId),
        'memberIds': members.isNotEmpty ? members : <String>[user.uid],
        'lastMessagePreview': preview,
        'lastSenderId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    try {
      await NotificationService.notifyMessageSent(
        caseId: caseId,
        senderId: user.uid,
        conversationId: conversationId,
        messageId: msgRef.id,
        preview: preview,
      );
    } catch (e, st) {
      await CrashlyticsService.recordError(e, st, reason: 'notifyMessageSent');
    }

    if (legalFlag != null) {
      try {
        await NotificationService.notifyCounselFlaggedMessage(
          caseId: caseId,
          legalFlag: legalFlag,
          preview: preview,
        );
      } catch (e, st) {
        await CrashlyticsService.recordError(
          e,
          st,
          reason: 'notifyCounselFlagged',
        );
      }
    }

    await CaseParticipantService.ensureParticipant(
      caseId: caseId,
      userId: user.uid,
    );
    await CaseParticipantService.incrementUnreadForOthers(
      caseId: caseId,
      senderId: user.uid,
      conversationId: conversationId,
    );

    unawaited(CustodyRiskInsightsService.refresh(caseId));
  }

  /// Recipient marks inbound messages as read (isRead = recipient has opened thread).
  static Future<void> markInboundRead({
    required String caseId,
    required String conversationId,
    required String readerUid,
    int batchLimit = 120,
  }) async {
    if (await UserRoleService.currentRole() == UserRole.attorney) {
      return;
    }
    final snap = await messagesRef(caseId, conversationId)
        .orderBy('createdAt', descending: true)
        .limit(batchLimit)
        .get();

    final write = _db.batch();
    var n = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['isRead'] == true) continue;
      final sender = data['senderId'] as String?;
      if (sender == null || sender == readerUid) continue;
      write.update(doc.reference, {'isRead': true});
      n++;
    }
    if (n > 0) await write.commit();

    await CaseParticipantService.resetUnreadForConversation(
      caseId: caseId,
      readerUid: readerUid,
      conversationId: conversationId,
    );
  }

  /// Update categorization tags (metadata only; message body stays immutable).
  static Future<void> updateMessageTags({
    required String caseId,
    required String conversationId,
    required String messageId,
    required List<String> tags,
  }) async {
    if (await UserRoleService.currentRole() == UserRole.attorney) {
      throw StateError('Attorney accounts cannot modify message metadata.');
    }
    await messagesRef(caseId, conversationId).doc(messageId).update({
      'tags': tags,
    });
  }

  /// Legal marks for the record (metadata only).
  static Future<void> updateMessageLegalMarks({
    required String caseId,
    required String conversationId,
    required String messageId,
    required bool important,
    required bool markedAsEvidence,
  }) async {
    if (await UserRoleService.currentRole() == UserRole.attorney) {
      throw StateError('Attorney accounts cannot modify message metadata.');
    }
    await messagesRef(caseId, conversationId).doc(messageId).update(<String, dynamic>{
      'important': important,
      'markedAsEvidence': markedAsEvidence,
    });
  }

  /// Last [limit] messages, oldest first — for exports & court summary JSON.
  static Future<List<Map<String, dynamic>>> fetchMessagesChronological({
    required String caseId,
    required String conversationId,
    int limit = 100,
    DateTime? rangeStartInclusive,
    DateTime? rangeEndInclusive,
  }) async {
    final needFilter = rangeStartInclusive != null || rangeEndInclusive != null;
    final fetchLimit = needFilter ? (limit * 3).clamp(100, 500) : limit;

    final snap = await messagesRef(caseId, conversationId)
        .orderBy('createdAt', descending: true)
        .limit(fetchLimit)
        .get();

    var list = snap.docs.map((d) {
      final m = Map<String, dynamic>.from(d.data());
      m['messageId'] = d.id;
      return m;
    }).toList();

    if (needFilter) {
      final start = rangeStartInclusive != null
          ? DateTime(
              rangeStartInclusive.year,
              rangeStartInclusive.month,
              rangeStartInclusive.day,
            )
          : null;
      final end = rangeEndInclusive != null
          ? DateTime(
              rangeEndInclusive.year,
              rangeEndInclusive.month,
              rangeEndInclusive.day,
              23,
              59,
              59,
              999,
            )
          : null;
      list = list.where((m) {
        final ts = m['createdAt'];
        if (ts is! Timestamp) return false;
        final d = ts.toDate();
        if (start != null && d.isBefore(start)) return false;
        if (end != null && d.isAfter(end)) return false;
        return true;
      }).toList();
      if (list.length > limit) {
        list = list.sublist(0, limit);
      }
    }

    return list.reversed.toList();
  }

  /// Structured payload for AI summarization / exports.
  static Future<Map<String, dynamic>> buildCourtSummaryPayload({
    required String caseId,
    required String conversationId,
    int messageLimit = 100,
  }) async {
    final messages = await fetchMessagesChronological(
      caseId: caseId,
      conversationId: conversationId,
      limit: messageLimit,
    );
    return <String, dynamic>{
      'schemaVersion': 1,
      'caseId': caseId,
      'conversationId': conversationId,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'messageCount': messages.length,
      'messages': messages
          .map(
            (m) => <String, dynamic>{
              'messageId': m['messageId'],
              'senderId': m['senderId'],
              'text': m['text'],
              'createdAt': _tsToIso(m['createdAt']),
              'isRead': m['isRead'],
              'type': m['type'],
              'tags': m['tags'] ?? [],
              'legalFlag': m['legalFlag'],
              'immutable': m['immutable'],
            },
          )
          .toList(),
    };
  }

  static String? _tsToIso(dynamic v) {
    if (v is Timestamp) return v.toDate().toUtc().toIso8601String();
    return null;
  }

  /// Unread count for [readerUid] in one conversation (client-filtered batch).
  static Future<int> countUnread({
    required String caseId,
    required String conversationId,
    required String readerUid,
    int scanLimit = 150,
  }) async {
    final snap = await messagesRef(caseId, conversationId)
        .orderBy('createdAt', descending: true)
        .limit(scanLimit)
        .get();

    var n = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['isRead'] == true) continue;
      final sender = data['senderId'] as String?;
      if (sender != null && sender != readerUid) n++;
    }
    return n;
  }

  /// PDF / print helpers — all messages chronological.
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchAllForExport(
    String caseId,
    String conversationId, {
    DateTime? since,
    bool flaggedOnly = false,
  }) async {
    final snap =
        await messagesRef(caseId, conversationId).orderBy('createdAt').get();

    var list = snap.docs;
    if (since != null) {
      final ts = Timestamp.fromDate(since);
      list = list.where((d) {
        final c = d.data()['createdAt'];
        if (c is! Timestamp) return false;
        return c.compareTo(ts) >= 0;
      }).toList();
    }
    if (flaggedOnly) {
      list = list.where((d) {
        final m = d.data();
        return m['legalFlag'] != null;
      }).toList();
    }
    return list;
  }

  /// Conversation list for the case inbox (newest [updatedAt] first; client-sorted).
  static Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      watchConversationsSorted(String caseId) =>
          _db
              .collection('cases')
              .doc(caseId)
              .collection('conversations')
              .snapshots()
              .map((snap) {
            final docs = snap.docs.toList()
              ..sort((a, b) {
                final ta = a.data()['updatedAt'];
                final tb = b.data()['updatedAt'];
                if (ta is Timestamp && tb is Timestamp) {
                  return tb.compareTo(ta);
                }
                if (ta is Timestamp) return -1;
                if (tb is Timestamp) return 1;
                return b.id.compareTo(a.id);
              });
            return docs;
          });
}
