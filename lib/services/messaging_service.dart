import '../models/case_event.dart';
import 'case_messaging_service.dart';
import 'event_logger_service.dart';
import 'structured_messaging.dart';

/// Structured messaging facade — all sends remain via [CaseMessagingService]; ledger rows optional.
class MessagingService {
  MessagingService._();

  static Future<void> sendText({
    required String caseId,
    required String conversationId,
    required String text,
    List<Map<String, dynamic>>? attachments,
  }) {
    return CaseMessagingService.sendTextMessage(
      caseId: caseId,
      conversationId: conversationId,
      text: text,
      attachments: attachments,
    );
  }

  /// System/in-app notices as ledger events (no chat document).
  static Future<void> emitSystemTimelineNotice({
    required String caseId,
    required String title,
    required String body,
    List<String> relatedIds = const [],
  }) {
    return EventLoggerService.logEventForCurrentUser(
      caseId: caseId,
      type: CaseEventTypes.statusChange,
      title: title,
      description: body,
      metadata: <String, dynamic>{
        'messageKind': StructuredMessageKind.systemEvent,
        'relatedIds': relatedIds,
      },
    );
  }
}
