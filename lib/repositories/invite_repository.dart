import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/relationship_models.dart';
import '../services/coparent_invite_code_service.dart'
    show AcceptCoparentCodeResult, CoparentInviteCodeService;
import '../services/invite_service.dart';

/// Production invite persistence and acceptance — delegates to Cloud Functions
/// (`coparentInvites`, `caseInvites`) for authoritative validation.
class InviteRepository {
  InviteRepository._();

  static final _db = FirebaseFirestore.instance;

  /// Creates a secure co-parent invite with `https://parentledger.org/invite/{token}` semantics.
  static Future<CoParentInviteSnapshot> createCoParentInvite() async {
    final result = await CoparentInviteCodeService.createInviteCode();
    return CoParentInviteSnapshot(
      code: result.token,
      universalLink: result.universalLink,
      deepLink: result.deepLink,
      expiresAt: result.expiresAtIso != null
          ? DateTime.tryParse(result.expiresAtIso!)
          : null,
    );
  }

  static Future<AcceptCoparentCodeResult> acceptCoParentShortCode(String raw) =>
      CoparentInviteCodeService.acceptCode(raw);

  static Future<Map<String, dynamic>> validateCaseInviteToken(String token) =>
      InviteService.validateCaseInviteToken(token);

  static Future<Map<String, dynamic>> acceptCaseInviteToken(String token) =>
      InviteService.acceptCaseInviteToken(token);

  /// Pending `caseInvites` created by the signed-in user (phone / legacy flows).
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchMyPendingCaseInvites() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _db
        .collection('caseInvites')
        .where('fromUserId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }
}
