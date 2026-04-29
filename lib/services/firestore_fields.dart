import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical participant-list field for `cases/{caseId}` and `conversations/{id}`.
///
/// Legacy case documents may still have `parents`; use [readCaseMemberIds] when
/// reading case data so old clients are merged into [memberIds] at read time.
class FirestoreFields {
  FirestoreFields._();

  static const String memberIds = 'memberIds';

  static const String _legacyCaseParents = 'parents';

  /// Reads case membership: prefers [memberIds], then legacy [_legacyCaseParents].
  static List<String> readCaseMemberIds(Map<String, dynamic> data) {
    final ids = data[memberIds];
    if (ids is List && ids.isNotEmpty) {
      return List<String>.from(ids.map((e) => e.toString()));
    }
    final legacy = data[_legacyCaseParents];
    if (legacy is List && legacy.isNotEmpty) {
      return List<String>.from(legacy.map((e) => e.toString()));
    }
    return [];
  }

  /// Merge onto `conversations/{id}` root when a message is sent (inbox + ordering).
  static Map<String, dynamic> mergeConversationThreadRoot({
    required String senderId,
    required String lastMessagePreview,
  }) =>
      <String, dynamic>{
        memberIds: FieldValue.arrayUnion([senderId]),
        'lastMessage': lastMessagePreview,
        'lastTimestamp': FieldValue.serverTimestamp(),
      };
}
