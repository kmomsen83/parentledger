import 'package:cloud_firestore/cloud_firestore.dart';

import 'case_paths.dart';

/// `cases/{caseId}/participants/{userId}` — membership + denormalized unread.
class CaseParticipantService {
  CaseParticipantService._();

  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> participantRef(
    String caseId,
    String userId,
  ) =>
      _db.collection('cases').doc(caseId).collection('participants').doc(userId);

  static Future<void> ensureParticipant({
    required String caseId,
    required String userId,
  }) async {
    await participantRef(caseId, userId).set(
      <String, dynamic>{
        'userId': userId,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// After another party sends a message, increment unread for all members except sender.
  /// [conversationId] scopes badges on the messages list (iMessage-style).
  static Future<void> incrementUnreadForOthers({
    required String caseId,
    required String senderId,
    required String conversationId,
  }) async {
    final caseSnap = await _db.collection('cases').doc(caseId).get();
    final members = List<String>.from(caseSnap.data()?['memberIds'] ?? []);
    if (members.isEmpty) return;

    final batch = _db.batch();
    final convKey = 'conversationUnread.$conversationId';
    for (final uid in members) {
      if (uid == senderId) continue;
      batch.set(
        participantRef(caseId, uid),
        <String, dynamic>{
          'userId': uid,
          'unreadMessageCount': FieldValue.increment(1),
          convKey: FieldValue.increment(1),
          'lastUnreadAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Clears unread for one thread and keeps [unreadMessageCount] aligned.
  static Future<void> resetUnreadForConversation({
    required String caseId,
    required String readerUid,
    required String conversationId,
  }) async {
    final ref = participantRef(caseId, readerUid);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final data = snap.data() ?? {};
      final raw = data['conversationUnread'];
      final map = Map<String, dynamic>.from(
        raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v)) : {},
      );
      final prev = (map[conversationId] as num?)?.toInt() ?? 0;
      map[conversationId] = 0;
      final global = (data['unreadMessageCount'] as num?)?.toInt() ?? 0;
      final nextGlobal = (global - prev).clamp(0, 1 << 30);

      txn.set(
        ref,
        <String, dynamic>{
          'conversationUnread': map,
          'unreadMessageCount': nextGlobal,
          'lastReadAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Legacy: zero entire inbox (e.g. migration). Prefer [resetUnreadForConversation].
  static Future<void> resetUnreadMessages({
    required String caseId,
    required String readerUid,
  }) async {
    await participantRef(caseId, readerUid).set(
      <String, dynamic>{
        'unreadMessageCount': 0,
        'conversationUnread': <String, dynamic>{},
        'lastReadAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> watchParticipant(
    String caseId,
    String userId,
  ) =>
      participantRef(caseId, userId).snapshots();

  static Future<int> getUnreadCount(String caseId, String userId) async {
    final doc = await participantRef(caseId, userId).get();
    final n = doc.data()?['unreadMessageCount'];
    if (n is int) return n;
    if (n is num) return n.toInt();
    return 0;
  }

  /// Unread in a single conversation (for list badges).
  ///
  /// When [conversationUnread] has not been backfilled yet, [caseWideFallback]
  /// can attribute case-level [unreadMessageCount] to the only thread (usually `primary`).
  static int unreadForConversation(
    Map<String, dynamic>? participantData,
    String conversationId, {
    int caseWideFallback = 0,
    int conversationListLength = 1,
  }) {
    final raw = participantData?['conversationUnread'];
    if (raw is Map) {
      final v = raw[conversationId];
      if (v is int && v > 0) return v;
      if (v is num && v.toInt() > 0) return v.toInt();
    }
    if (caseWideFallback > 0 &&
        conversationListLength == 1 &&
        conversationId == CasePaths.defaultConversationId) {
      return caseWideFallback;
    }
    return 0;
  }
}
