import 'package:cloud_firestore/cloud_firestore.dart';

import 'attorney_case_priority.dart';
import '../models/user_role.dart';
import 'attorney_case_status_service.dart';
import 'firestore_fields.dart';

/// Row model for attorney multi-client dashboard cards.
class AttorneyClientCardVm {
  const AttorneyClientCardVm({
    required this.caseId,
    required this.parentNamesLabel,
    required this.caseTitle,
    required this.isActive,
    required this.caseStatusLabel,
    required this.status,
    required this.lastActivityDisplay,
    required this.unreadNotificationsCount,
  });

  final String caseId;
  final String parentNamesLabel;

  /// Matter display name from `cases/{id}` (falls back if missing).
  final String caseTitle;

  /// Derived from link metadata + whether both parents appear on the matter.
  final bool isActive;

  /// Counsel-facing badge: Active / Pending / Closed.
  final String caseStatusLabel;
  final AttorneyCaseStatus status;
  final DateTime? lastActivityDisplay;

  /// Unread in-app notifications tagged with this [caseId] (counsel inbox).
  final int unreadNotificationsCount;
}

class AttorneyClientCardLoader {
  AttorneyClientCardLoader._();

  static final _db = FirebaseFirestore.instance;

  static String _nameFromUserDoc(Map<String, dynamic>? d) {
    if (d == null) return 'Parent';
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

  static String _caseTitleFromData(Map<String, dynamic>? caseData) {
    if (caseData == null) return 'Co-parenting matter';
    for (final key in ['caseName', 'title', 'name', 'matterTitle']) {
      final v = (caseData[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return 'Co-parenting matter';
  }

  static Future<AttorneyClientCardVm> load({
    required String caseId,
    required Map<String, dynamic> attorneyLinkRow,
    int unreadNotificationsCount = 0,
  }) async {
    final caseSnap = await _db.collection('cases').doc(caseId).get();
    final caseData = caseSnap.data();
    final caseTitle = _caseTitleFromData(caseData);

    final status = await AttorneyCaseStatusService.compute(caseId);

    final ids = FirestoreFields.readCaseMemberIds(caseData ?? {});
    final userSnaps = await Future.wait(
      ids.map((id) => _db.collection('users').doc(id).get()),
    );

    final namesForLabel = <String>[];
    var parentCount = 0;
    for (final s in userSnaps) {
      final role = UserRole.fromObject(s.data()?['role']);
      if (role.isAttorney) continue;
      parentCount++;
      if (namesForLabel.length < 2) {
        namesForLabel.add(_nameFromUserDoc(s.data()));
      }
    }

    final linkStatus =
        (attorneyLinkRow['status'] ?? 'active').toString().toLowerCase();
    final isActive = linkStatus != 'pending' && parentCount >= 2;

    final String caseStatusLabel;
    if (linkStatus == 'closed' ||
        linkStatus == 'archived' ||
        linkStatus == 'inactive') {
      caseStatusLabel = 'Closed';
    } else if (linkStatus == 'pending' || parentCount < 2) {
      caseStatusLabel = 'Pending';
    } else {
      caseStatusLabel = 'Active';
    }

    String parentNamesLabel;
    if (namesForLabel.isEmpty) {
      parentNamesLabel = 'Clients';
    } else if (namesForLabel.length == 1) {
      parentNamesLabel = namesForLabel.first;
    } else {
      parentNamesLabel = '${namesForLabel[0]} & ${namesForLabel[1]}';
    }

    return AttorneyClientCardVm(
      caseId: caseId,
      parentNamesLabel: parentNamesLabel,
      caseTitle: caseTitle,
      isActive: isActive,
      caseStatusLabel: caseStatusLabel,
      status: status,
      lastActivityDisplay: status.lastActivityAt,
      unreadNotificationsCount: unreadNotificationsCount,
    );
  }

  static Future<Map<String, int>> _unreadNotificationsByCase(
    String attorneyUid,
  ) async {
    final map = <String, int>{};
    try {
      final snap = await _db
          .collection('notifications')
          .doc(attorneyUid)
          .collection('items')
          .where('read', isEqualTo: false)
          .get();
      for (final d in snap.docs) {
        final raw = d.data()['caseId'];
        final cid = raw == null ? '' : raw.toString().trim();
        if (cid.isEmpty) continue;
        map[cid] = (map[cid] ?? 0) + 1;
      }
    } catch (_) {
      // Non-fatal: dashboard still lists matters without per-case unread.
    }
    return map;
  }

  static Future<List<AttorneyClientCardVm>> loadAll(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> linkDocs,
    String attorneyUid,
  ) async {
    final unreadByCase = await _unreadNotificationsByCase(attorneyUid);
    final out = await Future.wait(
      linkDocs.map((doc) async {
        final data = doc.data();
        final caseId = (data['caseId'] ?? doc.id).toString();
        final unread = unreadByCase[caseId] ?? 0;
        return load(
          caseId: caseId,
          attorneyLinkRow: data,
          unreadNotificationsCount: unread,
        );
      }),
    );
    out.sort((a, b) {
      final ra = AttorneyCasePriorityResolver.sortRank(a.status.priority);
      final rb = AttorneyCasePriorityResolver.sortRank(b.status.priority);
      if (ra != rb) return ra.compareTo(rb);
      final aTs = a.lastActivityDisplay?.millisecondsSinceEpoch ?? 0;
      final bTs = b.lastActivityDisplay?.millisecondsSinceEpoch ?? 0;
      if (aTs != bTs) return bTs.compareTo(aTs);
      if (a.status.issueCount != b.status.issueCount) {
        return b.status.issueCount.compareTo(a.status.issueCount);
      }
      return a.caseId.compareTo(b.caseId);
    });
    return out;
  }
}
