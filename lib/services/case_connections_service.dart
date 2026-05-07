import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

enum CaseConnectionKind { coParent, attorney }

class CaseConnectionRow {
  const CaseConnectionRow({
    required this.userId,
    required this.displayName,
    required this.kind,
  });

  final String userId;
  final String displayName;
  final CaseConnectionKind kind;
}

/// Loads linked people for a case and performs HTTPS removals (server-side only).
class CaseConnectionsService {
  CaseConnectionsService._();

  static final _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static String displayNameFromUserDoc(Map<String, dynamic>? d) {
    if (d == null) return 'User';
    final dn = (d['displayName'] ?? '').toString().trim();
    if (dn.isNotEmpty) return dn;
    final fn = (d['firstName'] ?? '').toString().trim();
    final ln = (d['lastName'] ?? '').toString().trim();
    final full = '$fn $ln'.trim();
    if (full.isNotEmpty) return full;
    return 'User';
  }

  /// Resolves co-parents and attorneys via `caseMembers` + case `memberIds` fallback.
  static Future<List<CaseConnectionRow>> buildRows({
    required String caseId,
    required String myUid,
    required List<String> memberIdsFromCase,
  }) async {
    final db = FirebaseFirestore.instance;
    final qs =
        await db.collection('caseMembers').where('caseId', isEqualTo: caseId).get();

    final byUserId = <String, Map<String, dynamic>>{};
    for (final doc in qs.docs) {
      final data = doc.data();
      final uid = data['userId']?.toString() ?? '';
      if (uid.isEmpty) continue;
      byUserId[uid] = data;
    }

    final out = <CaseConnectionRow>[];
    final seen = <String>{};

    for (final e in byUserId.entries) {
      final uid = e.key;
      if (uid == myUid) continue;
      seen.add(uid);
      final role = (e.value['role'] ?? 'parent').toString().toLowerCase();
      final userSnap = await db.collection('users').doc(uid).get();
      final kind =
          role == 'attorney' ? CaseConnectionKind.attorney : CaseConnectionKind.coParent;
      out.add(
        CaseConnectionRow(
          userId: uid,
          displayName: displayNameFromUserDoc(userSnap.data()),
          kind: kind,
        ),
      );
    }

    for (final uid in memberIdsFromCase) {
      if (uid == myUid || seen.contains(uid)) continue;
      seen.add(uid);
      final userSnap = await db.collection('users').doc(uid).get();
      final role =
          (userSnap.data()?['role'] ?? 'parent').toString().toLowerCase();
      final kind =
          role == 'attorney' ? CaseConnectionKind.attorney : CaseConnectionKind.coParent;
      out.add(
        CaseConnectionRow(
          userId: uid,
          displayName: displayNameFromUserDoc(userSnap.data()),
          kind: kind,
        ),
      );
    }

    out.sort((a, b) {
      if (a.kind != b.kind) {
        return a.kind == CaseConnectionKind.coParent ? -1 : 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return out;
  }

  static Future<void> removeCoParent(String targetUserId) async {
    final callable = _functions.httpsCallable('removeCoParentFromCase');
    await callable.call(<String, dynamic>{'targetUserId': targetUserId});
  }

  static Future<void> revokeAttorney(String attorneyUserId) async {
    final callable = _functions.httpsCallable('revokeAttorneyCaseAccess');
    await callable.call(<String, dynamic>{'attorneyUserId': attorneyUserId});
  }

  static String mapFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'permission-denied':
        return e.message ?? 'You cannot change this connection.';
      case 'failed-precondition':
        return e.message ?? 'This action could not be completed.';
      case 'invalid-argument':
        return e.message ?? 'Invalid request.';
      case 'resource-exhausted':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }
}
