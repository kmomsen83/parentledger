import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_role.dart';
import 'attorney_notification_preferences.dart';
import 'firestore_fields.dart';

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

  /// Unread count respecting counsel category toggles ([AttorneyNotificationPreferences]).
  static Stream<int> watchCounselFilteredUnreadCount(String userId) => itemsCol(userId)
      .where('read', isEqualTo: false)
      .snapshots()
      .asyncMap((snap) async {
        final prefs = await AttorneyNotificationPreferences.loadAll();
        var n = 0;
        for (final d in snap.docs) {
          final raw = d.data()['counselCategory'];
          final cat = raw == null ? '' : raw.toString();
          if (cat.isEmpty) {
            n++;
            continue;
          }
          if (prefs[cat] ?? true) {
            n++;
          }
        }
        return n;
      });

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
    String? counselCategory,
  }) async {
    await itemsCol(userId).add(<String, dynamic>{
      'type': type,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      'caseId': caseId,
      if (counselCategory != null && counselCategory.isNotEmpty)
        'counselCategory': counselCategory,
      if (metadata != null) 'metadata': metadata,
    });
  }

  static String _shortName(Map<String, dynamic>? d) {
    if (d == null) return 'Clients';
    final dn = (d['displayName'] ?? '').toString().trim();
    if (dn.isNotEmpty) return dn;
    final fn = (d['firstName'] ?? '').toString().trim();
    final ln = (d['lastName'] ?? '').toString().trim();
    final full = '$fn $ln'.trim();
    if (full.isNotEmpty) return full;
    final em = (d['email'] ?? '').toString().trim();
    if (em.isNotEmpty) return em.split('@').first;
    return 'Parent';
  }

  /// Display label such as `John & Sarah` for counsel-facing titles.
  static Future<String> counselCaseLabel(String caseId) async {
    final caseSnap = await _db.collection('cases').doc(caseId).get();
    final ids = FirestoreFields.readCaseMemberIds(caseSnap.data() ?? {});
    if (ids.isEmpty) return 'Clients';

    final snaps =
        await Future.wait(ids.map((id) => _db.collection('users').doc(id).get()));

    final names = <String>[];
    for (final s in snaps) {
      final role = UserRole.fromObject(s.data()?['role']);
      if (role.isAttorney) continue;
      names.add(_shortName(s.data()));
      if (names.length >= 2) break;
    }
    if (names.isEmpty) return 'Clients';
    if (names.length == 1) return names.first;
    return '${names[0]} & ${names[1]}';
  }

  static Future<List<String>> attorneyUserIdsForCase(String caseId) async {
    try {
      final q = await _db
          .collection('caseMembers')
          .where('caseId', isEqualTo: caseId)
          .where('role', isEqualTo: 'attorney')
          .get();
      final out = <String>[];
      for (final d in q.docs) {
        final uid = (d.data()['userId'] ?? '').toString().trim();
        if (uid.isNotEmpty) out.add(uid);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _notifyCounsel({
    required String caseId,
    required String counselCategory,
    required String title,
    required String body,
    Map<String, dynamic>? metadata,
    String? excludeUserId,
  }) async {
    if (!await AttorneyNotificationPreferences.isCategoryEnabled(counselCategory)) {
      return;
    }
    final attorneys = await attorneyUserIdsForCase(caseId);
    final recipients = excludeUserId == null
        ? attorneys
        : attorneys.where((u) => u != excludeUserId).toList();
    if (recipients.isEmpty) return;

    await Future.wait(
      recipients.map(
        (uid) => _create(
          userId: uid,
          type: 'alert',
          title: title,
          body: body,
          caseId: caseId,
          counselCategory: counselCategory,
          metadata: metadata,
        ),
      ),
    );
  }

  /// Missed / overdue exchange signals (aggregated custody metrics).
  static Future<void> notifyCounselMissedExchanges({
    required String caseId,
    required int totalMissed,
  }) async {
    if (totalMissed <= 0) return;
    final label = await counselCaseLabel(caseId);
    final title =
        '$label: $totalMissed missed exchange${totalMissed == 1 ? '' : 's'} detected';
    await _notifyCounsel(
      caseId: caseId,
      counselCategory: AttorneyNotificationPreferences.catExchange,
      title: title,
      body: 'Review the custody schedule and exchange timeline for this matter.',
      metadata: <String, dynamic>{'totalMissed': totalMissed},
    );
  }

  /// Hostile or non-compliant classifier output on a new message.
  static Future<void> notifyCounselFlaggedMessage({
    required String caseId,
    required String legalFlag,
    required String preview,
  }) async {
    final label = await counselCaseLabel(caseId);
    final safe = preview.trim().isEmpty ? 'New flagged message' : preview;
    await _notifyCounsel(
      caseId: caseId,
      counselCategory: AttorneyNotificationPreferences.catFlaggedMessage,
      title: '$label: flagged message ($legalFlag)',
      body: safe.length > 200 ? '${safe.substring(0, 200)}…' : safe,
      metadata: <String, dynamic>{'legalFlag': legalFlag},
    );
  }

  /// Another party uploaded a document to the shared library.
  static Future<void> notifyCounselDocumentUploaded({
    required String caseId,
    required String title,
    String? excludeUploaderUid,
  }) async {
    final label = await counselCaseLabel(caseId);
    final t = title.trim().isEmpty ? 'New document' : title.trim();
    await _notifyCounsel(
      caseId: caseId,
      counselCategory: AttorneyNotificationPreferences.catDocument,
      title: '$label: document uploaded',
      body: t,
      excludeUserId: excludeUploaderUid,
      metadata: <String, dynamic>{'documentTitle': t},
    );
  }

  /// Material change in computed custody risk (score / level).
  static Future<void> notifyCounselRiskActivity({
    required String caseId,
    required String summary,
  }) async {
    final label = await counselCaseLabel(caseId);
    await _notifyCounsel(
      caseId: caseId,
      counselCategory: AttorneyNotificationPreferences.catActivity,
      title: '$label: case activity alert',
      body: summary,
    );
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
