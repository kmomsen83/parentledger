import 'package:cloud_firestore/cloud_firestore.dart';

/// Ensures counsel only opens matters linked on `users/{uid}/cases`.
class AttorneyCaseAccessService {
  AttorneyCaseAccessService._();

  static final _db = FirebaseFirestore.instance;

  /// True if [attorneyUid] has a row for this matter (doc id or `caseId` field).
  static Future<bool> attorneyHasAccess({
    required String attorneyUid,
    required String caseId,
  }) async {
    final trimmed = caseId.trim();
    if (trimmed.isEmpty) return false;

    final col = _db.collection('users').doc(attorneyUid).collection('cases');
    final byDocId = await col.doc(trimmed).get();
    if (byDocId.exists) return true;

    final q = await col.where('caseId', isEqualTo: trimmed).limit(1).get();
    return q.docs.isNotEmpty;
  }
}
