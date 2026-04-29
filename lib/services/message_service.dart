import 'package:cloud_firestore/cloud_firestore.dart';

import 'case_messaging_service.dart';

/// Legacy facade — all data lives under
/// `cases/{caseId}/conversations/{conversationId}/messages`.
class MessageService {
  MessageService._();

  static Future<void> sendCaseTextMessage({
    required String caseId,
    required String text,
  }) =>
      CaseMessagingService.sendTextMessage(
        caseId: caseId,
        conversationId: CaseMessagingService.defaultConversationId,
        text: text,
      );

  static Future<void> markIncomingUnreadAsRead({
    required String caseId,
    required String readerUid,
    int limit = 100,
  }) =>
      CaseMessagingService.markInboundRead(
        caseId: caseId,
        conversationId: CaseMessagingService.defaultConversationId,
        readerUid: readerUid,
        batchLimit: limit,
      );

  static Future<List<QueryDocumentSnapshot>> getMessagesForExport(
    String caseId, {
    DateTime? since,
    bool flaggedOnly = false,
  }) =>
      CaseMessagingService.fetchAllForExport(
        caseId,
        CaseMessagingService.defaultConversationId,
        since: since,
        flaggedOnly: flaggedOnly,
      );

  static String messageBodyForDisplay(Map<String, dynamic> m) =>
      (m['text'] ?? m['messageText'] ?? '').toString();

  /// Chronological transcript for AI / exports (oldest → newest).
  static Future<String> buildThreadTranscript(
    String caseId,
    String conversationId, {
    int limit = 120,
  }) async {
    final snap = await CaseMessagingService.messagesRef(caseId, conversationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final buf = StringBuffer();
    for (final d in snap.docs.reversed) {
      final m = d.data();
      final body = messageBodyForDisplay(m).trim();
      if (body.isEmpty) continue;
      final ts = m['createdAt'];
      var tsLabel = '';
      if (ts is Timestamp) {
        tsLabel = ts.toDate().toUtc().toIso8601String();
      }
      final sender = (m['senderId'] ?? '').toString();
      buf.writeln('[$tsLabel] $sender: $body');
    }
    return buf.toString().trim();
  }
}
