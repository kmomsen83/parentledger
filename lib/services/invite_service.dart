import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'event_logger_service.dart';


class InviteService {
  static final _db = FirebaseFirestore.instance;
  static final _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  static const _uuid = Uuid();

  /// Pending invite from deep link (consumed by [checkAndAcceptInvite]).
  static String? pendingInviteId;
  static String? pendingInviteToken;

  static const String _inviteBaseUrl = 'https://parentledger.app/invite';

  /// New token-based invite creation.
  static Future<String> createInvite({
    required String caseId,
    required String role,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole != 'coparent' && normalizedRole != 'attorney') {
      throw Exception('Invalid role. Must be coparent or attorney.');
    }
    final token = _uuid.v4();
    final inviteRef = _db.collection('caseInvites').doc();
    final maxUses = normalizedRole == 'coparent' ? 1 : 3;

    await inviteRef.set(<String, dynamic>{
      'caseId': caseId,
      'createdBy': user.uid,
      'role': normalizedRole,
      'token': token,
      'status': 'pending',
      'maxUses': maxUses,
      'uses': 0,
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 48)),
      ),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await EventLoggerService.logEventForActor(
      caseId: caseId,
      type: 'invite_sent',
      title: 'Invite sent',
      description: 'A $normalizedRole invite was created.',
      actorId: user.uid,
      metadata: <String, dynamic>{
        'inviteId': inviteRef.id,
        'role': normalizedRole,
      },
    );

    return '$_inviteBaseUrl?token=$token';
  }

  static Future<Map<String, dynamic>> validateCaseInviteToken(
    String token,
  ) async {
    final callable = _functions.httpsCallable('validateCaseInvite');
    final result = await callable.call(<String, dynamic>{'token': token});
    return Map<String, dynamic>.from(
      (result.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }

  static Future<Map<String, dynamic>> acceptCaseInviteToken(String token) async {
    final callable = _functions.httpsCallable('acceptCaseInvite');
    final result = await callable.call(<String, dynamic>{'token': token});
    return Map<String, dynamic>.from(
      (result.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }

  /// Accept invite: transaction on Firestore (client-side).
  static Future<void> acceptInvite(String inviteId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final callable = _functions.httpsCallable('acceptInvite');
      await callable.call(<String, dynamic>{'inviteId': inviteId});
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('acceptInvite callable failed: ${e.code} ${e.message}');
      }
      rethrow;
    }

    await _handleMergeIfNeeded(user.uid);
    // `invite_accepted` is recorded by the `acceptInvite` Cloud Function (hashed ledger).
  }

  /// Shareable attorney invite (no phone required). Returns new [caseInvites] document id.
  static Future<String> createAttorneyInvite({
    required String caseId,
    required String fromUserId,
    String? intendedRecipientEmail,
    String? intendedRecipientUserId,
  }) async {
    // Kept for call-site compatibility; backend derives canonical sender/case.
    assert(caseId.isNotEmpty && fromUserId.isNotEmpty);
    // Backend callable ensures canonical lifecycle mirroring, logging, and
    // intended-recipient binding checks.
    final callable = _functions.httpsCallable('createCaseInvite');
    final result = await callable.call(<String, dynamic>{
      'role': 'attorney',
      'toPhone': '',
      'intendedRecipientEmail': intendedRecipientEmail?.trim().toLowerCase(),
      'intendedRecipientUserId': intendedRecipientUserId?.trim(),
    });
    final data = Map<String, dynamic>.from(
      (result.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    final inviteId = (data['inviteId'] ?? '').toString();
    if (inviteId.isEmpty) {
      throw Exception('Could not create attorney invite.');
    }
    return inviteId;
  }

  static Future<Map<String, dynamic>> validateInvite(String inviteId) async {
    final callable = _functions.httpsCallable('validateInvite');
    final result = await callable.call(<String, dynamic>{'inviteId': inviteId});
    final data = Map<String, dynamic>.from(
      (result.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    return data;
  }

  static Future<void> _handleMergeIfNeeded(String userId) async {
    final userRef = _db.collection('users').doc(userId);
    final userSnap = await userRef.get();

    final data = userSnap.data();
    final mergeFrom = data?['mergeFromCaseId'];
    final newCaseId = data?['caseId'];

    if (mergeFrom == null || newCaseId == null) return;

    final oldChildren = await _db
        .collection('cases')
        .doc(mergeFrom)
        .collection('children')
        .get();

    for (final doc in oldChildren.docs) {
      await _db
          .collection('cases')
          .doc(newCaseId)
          .collection('children')
          .add(doc.data());
    }

    await userRef.update({
      'mergeFromCaseId': FieldValue.delete(),
    });
  }

  static Future<void> checkAndAcceptInvite(User user) async {
    if (pendingInviteId != null) {
      final inviteId = pendingInviteId!;
      pendingInviteId = null;
      try {
        await acceptInvite(inviteId);
      } catch (_) {
        if (kDebugMode) {
          debugPrint('Invite accept failed');
        }
      }
      return;
    }

    final phone = user.phoneNumber;
    try {
      if (phone != null && phone.isNotEmpty) {
        final phoneInvites = await _db
            .collection('caseInvites')
            .where('toPhone', isEqualTo: phone)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();
        if (phoneInvites.docs.isNotEmpty) {
          await acceptInvite(phoneInvites.docs.first.id);
          return;
        }
      }

      final email = user.email?.trim().toLowerCase();
      if (email != null && email.isNotEmpty) {
        final emailInvites = await _db
            .collection('caseInvites')
            .where('intendedRecipient.email', isEqualTo: email)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();
        if (emailInvites.docs.isNotEmpty) {
          await acceptInvite(emailInvites.docs.first.id);
        }
      }
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Invite lookup failed');
      }
    }
  }
}
