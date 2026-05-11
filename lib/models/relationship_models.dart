import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical co-parent link state stored on [users] and implied by [cases.memberIds].
enum CoParentRelationshipStatus {
  none,
  pendingInvite,
  linked,
  disconnected,
}

CoParentRelationshipStatus coParentRelationshipStatusFromObject(Object? raw) {
  final s = raw?.toString().trim().toLowerCase() ?? '';
  switch (s) {
    case 'pending_invite':
    case 'pendinginvite':
      return CoParentRelationshipStatus.pendingInvite;
    case 'linked':
    case 'active':
      return CoParentRelationshipStatus.linked;
    case 'disconnected':
    case 'removed':
      return CoParentRelationshipStatus.disconnected;
    default:
      return CoParentRelationshipStatus.none;
  }
}

/// Server-backed co-parent invite snapshot (backed by `coparentInvites` via Cloud Functions).
class CoParentInviteSnapshot {
  const CoParentInviteSnapshot({
    required this.code,
    required this.universalLink,
    required this.deepLink,
    this.expiresAt,
  });

  final String code;
  final String universalLink;
  final String deepLink;
  final DateTime? expiresAt;

  static CoParentInviteSnapshot? fromCallableResult(Map<String, dynamic> map) {
    final token = map['token']?.toString().trim() ?? '';
    if (token.isEmpty) return null;
    final universal =
        (map['universalLink'] ?? map['universalUrl'])?.toString().trim() ?? '';
    final deep = (map['deepLink'] ?? map['appDeepLink'])?.toString().trim() ?? '';
    DateTime? exp;
    final expRaw = map['expiresAt'];
    if (expRaw is Timestamp) {
      exp = expRaw.toDate();
    }
    return CoParentInviteSnapshot(
      code: token,
      universalLink: universal,
      deepLink: deep,
      expiresAt: exp,
    );
  }
}
