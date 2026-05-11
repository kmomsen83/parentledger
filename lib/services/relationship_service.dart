import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/relationship_models.dart';

/// Co-parent and shared-household helpers. In ParentLedger, a **case** is the shared
/// household: `cases/{caseId}` holds `memberIds`, custody, calendar, expenses, and threads.
class RelationshipService {
  RelationshipService._();

  static final _db = FirebaseFirestore.instance;

  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Active case / household id from the signed-in user's profile.
  static Future<String?> householdCaseIdForCurrentUser() async {
    final uid = currentUid;
    if (uid == null) return null;
    final snap = await _db.collection('users').doc(uid).get();
    final id = snap.data()?['caseId']?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  }

  /// Other parent uid in the same household when exactly two parents are members.
  static Future<String?> coParentUserId(String caseId) async {
    final snap = await _db.collection('cases').doc(caseId).get();
    final members = List<String>.from(snap.data()?['memberIds'] ?? const <String>[]);
    final uid = currentUid;
    if (uid == null) return null;
    for (final m in members) {
      if (m != uid) {
        final u = await _db.collection('users').doc(m).get();
        final role = (u.data()?['role'] ?? 'parent').toString().toLowerCase();
        if (role != 'attorney') return m;
      }
    }
    return null;
  }

  static CoParentRelationshipStatus relationshipStatusForUserDoc(
    Map<String, dynamic>? user,
    String caseId,
  ) {
    if (user == null || caseId.isEmpty) return CoParentRelationshipStatus.none;
    final cid = user['caseId']?.toString().trim() ?? '';
    if (cid.isEmpty) return CoParentRelationshipStatus.none;
    final explicit = coParentRelationshipStatusFromObject(user['coParentRelationshipStatus']);
    if (explicit != CoParentRelationshipStatus.none) return explicit;
    final coparent = user['coParentId']?.toString().trim() ?? '';
    if (coparent.isNotEmpty) return CoParentRelationshipStatus.linked;
    return CoParentRelationshipStatus.none;
  }

  /// Whether [candidateUid] is already in the case roster (duplicate link guard at UI layer;
  /// authoritative checks remain in Cloud Functions).
  static Future<bool> isUserInHousehold({
    required String caseId,
    required String candidateUid,
  }) async {
    final snap = await _db.collection('cases').doc(caseId).get();
    final members = List<String>.from(snap.data()?['memberIds'] ?? const <String>[]);
    return members.contains(candidateUid);
  }
}
