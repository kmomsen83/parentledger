import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Storage paths for timeline-linked attachments (immutable uploads).
class EventAttachmentService {
  EventAttachmentService._();

  static Reference refForCaseMessageAttachment({
    required String caseId,
    required String conversationId,
    required String messageId,
    required String fileName,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    return FirebaseStorage.instance.ref(
      'cases/$caseId/conversations/$conversationId/messages/$messageId/$uid/$safe',
    );
  }

  static Reference refForCaseDocument({
    required String caseId,
    required String docId,
    required String fileName,
  }) {
    final safe = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    return FirebaseStorage.instance.ref(
      'cases/$caseId/documents/$docId/$safe',
    );
  }
}
