import 'package:cloud_firestore/cloud_firestore.dart';

import 'case_paths.dart';

/// Canonical case messaging threads (conversation document ids → display titles).
class CaseThreadCatalog {
  CaseThreadCatalog._();

  /// Order shown in the thread list (dashboard “case file” inbox).
  static const List<String> orderedThreadIds = [
    CasePaths.defaultConversationId,
    'schedule',
    'expenses',
    'disputes',
  ];

  static bool isStandardThread(String conversationId) =>
      orderedThreadIds.contains(conversationId);

  static String defaultTitleForId(String id) {
    switch (id) {
      case CasePaths.defaultConversationId:
        return 'General Communication';
      case 'schedule':
        return 'Schedule Discussion';
      case 'expenses':
        return 'Expenses';
      case 'disputes':
        return 'Messages';
      default:
        return 'Messages';
    }
  }

  /// Prefer stored [title] on the conversation doc; fall back to catalog / legacy labels.
  static String threadTitle(String conversationId, Map<String, dynamic>? data) {
    final t = (data?['title'] ?? '').toString().trim();
    if (t == 'Disputes') return 'Messages';
    if (t.isNotEmpty && t != 'Case discussion') {
      return t;
    }
    return defaultTitleForId(conversationId);
  }

  /// Stable inbox ordering: catalog threads first, then others by [updatedAt] desc.
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> sortInboxThreads(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int rank(String id) {
      final i = orderedThreadIds.indexOf(id);
      return i >= 0 ? i : 1000;
    }

    final copy = [...docs];
    copy.sort((a, b) {
      final ra = rank(a.id);
      final rb = rank(b.id);
      if (ra != rb) return ra.compareTo(rb);
      final ta = a.data()['updatedAt'];
      final tb = b.data()['updatedAt'];
      if (ta is Timestamp && tb is Timestamp) {
        return tb.compareTo(ta);
      }
      if (ta is Timestamp) return -1;
      if (tb is Timestamp) return 1;
      return a.id.compareTo(b.id);
    });
    return copy;
  }
}
