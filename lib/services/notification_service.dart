import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// In-app inbox. Structured audit history lives in `caseEvents` ([EventLoggerService]).
class NotificationService {
  NotificationService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> itemsCol(String userId) =>
      _db.collection('notifications').doc(userId).collection('items');

  /// IMPORTANT: Single Firestore listener per returned stream; one primary [StreamBuilder] etc.
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchUserNotifications(
    String userId,
  ) =>
      itemsCol(userId).orderBy('createdAt', descending: true).snapshots();

  /// Single-subscription stream — use at most one [StreamBuilder] consumer per mounted subtree.
  static Stream<int> watchUnreadCount(String userId) =>
      itemsCol(userId)
          .where('read', isEqualTo: false)
          .snapshots()
          .map((s) => s.docs.length);

  static Future<void> markAllAsRead(String userId) async {
    final batch = _db.batch();
    final snapshot = await itemsCol(userId).where('read', isEqualTo: false).get();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, <String, dynamic>{'read': true});
    }
    await batch.commit();
  }

  static Future<void> markRead({
    required String userId,
    required String notificationId,
  }) =>
      itemsCol(userId).doc(notificationId).update(<String, dynamic>{'read': true});

  static Future<void> _create({
    required String userId,
    required String type,
    required String title,
    required String body,
    required String caseId,
    Map<String, dynamic>? metadata,
  }) async {
    await itemsCol(userId).add(<String, dynamic>{
      'type': type,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      'caseId': caseId,
      if (metadata != null) 'metadata': metadata,
    });
  }

  static Future<List<String>> _caseMemberIds(String caseId) async {
    final caseSnap = await _db.collection('cases').doc(caseId).get();
    return List<String>.from(caseSnap.data()?['memberIds'] ?? const <String>[]);
  }

  static Future<void> _notifyCaseMembers({
    required String caseId,
    required List<String> recipients,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? metadata,
  }) async {
    if (recipients.isEmpty) return;
    await Future.wait(
      recipients.map(
        (uid) => _create(
          userId: uid,
          type: type,
          title: title,
          body: body,
          caseId: caseId,
          metadata: metadata,
        ),
      ),
    );
  }

  static Future<void> notifyMessageSent({
    required String caseId,
    required String senderId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {
    final members = await _caseMemberIds(caseId);
    final recipients = members.where((m) => m != senderId).toList();
    final safePreview = preview.trim();
    await _notifyCaseMembers(
      caseId: caseId,
      recipients: recipients,
      type: 'message',
      title: 'New message',
      body: safePreview.isEmpty ? 'You have a new message.' : safePreview,
      metadata: <String, dynamic>{
        'conversationId': conversationId,
        'messageId': messageId,
      },
    );
  }

  static Future<void> notifyExpenseCreated({
    required String caseId,
    required String createdBy,
    required String expenseId,
    required double amount,
    required String description,
  }) async {
    final members = await _caseMemberIds(caseId);
    final recipients = members.where((m) => m != createdBy).toList();
    await _notifyCaseMembers(
      caseId: caseId,
      recipients: recipients,
      type: 'expense',
      title: '\$${amount.toStringAsFixed(2)} expense added',
      body: description.trim().isEmpty ? 'A new shared expense was added.' : description,
      metadata: <String, dynamic>{'expenseId': expenseId},
    );
  }

  static Future<void> notifyExpenseStatusChanged({
    required String caseId,
    required String expenseId,
    required String creatorUid,
    required bool approved,
  }) async {
    await _create(
      userId: creatorUid,
      type: 'expense',
      title: approved ? 'Expense approved' : 'Expense denied',
      body: approved
          ? 'Your submitted expense was approved.'
          : 'Your submitted expense was denied.',
      caseId: caseId,
      metadata: <String, dynamic>{'expenseId': expenseId, 'approved': approved},
    );
  }

  static Future<void> notifyExchangeScheduled({
    required String caseId,
    required String createdBy,
    required String exchangeId,
    required DateTime scheduledTime,
  }) async {
    final members = await _caseMemberIds(caseId);
    final recipients = members.where((m) => m != createdBy).toList();
    final local = scheduledTime.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    await _notifyCaseMembers(
      caseId: caseId,
      recipients: recipients,
      type: 'system',
      title: 'Pickup scheduled for $hh:$mm',
      body: 'A new exchange was added to your schedule.',
      metadata: <String, dynamic>{'exchangeId': exchangeId},
    );
  }

  static Future<void> notifyReportGenerated({
    required String caseId,
    required String userId,
    required String reportTitle,
  }) async {
    await _create(
      userId: userId,
      type: 'system',
      title: 'Case report ready',
      body: '$reportTitle is ready to view.',
      caseId: caseId,
      metadata: <String, dynamic>{'reportTitle': reportTitle},
    );
  }

  static String? currentUid() => FirebaseAuth.instance.currentUser?.uid;
}
