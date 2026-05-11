import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';

/// Normalizes Firebase callable payloads and maps [FirebaseFunctionsException]
/// to user-facing copy (invite flows).
class InviteCallableUtils {
  InviteCallableUtils._();

  /// Converts [HttpsCallableResult.data] to a flat string-keyed map.
  static Map<String, dynamic> normalizeData(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return Map<String, dynamic>.from(
        data.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
      );
    }
    developer.log(
      'Callable returned non-Map: ${data.runtimeType}',
      name: 'InviteFlow',
    );
    return {};
  }

  /// Picks a non-empty invite token from common server field names.
  static String? pickInviteToken(Map<String, dynamic> m) {
    for (final key in const [
      'token',
      'inviteToken',
      'inviteId',
      'id',
    ]) {
      final raw = m[key];
      if (raw == null) continue;
      final s = raw.toString().trim();
      if (s.isEmpty) continue;
      if (s == 'true' || s == 'false') continue;
      return s;
    }
    final nested = m['data'];
    if (nested is Map) {
      return pickInviteToken(normalizeData(nested));
    }
    final wrapped = m['result'];
    if (wrapped is Map) {
      return pickInviteToken(normalizeData(wrapped));
    }
    return null;
  }

  static String userMessageFor(FirebaseFunctionsException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    switch (code) {
      case 'failed-precondition':
        if (msg.contains('case') &&
            (msg.contains('belong') || msg.contains('invite'))) {
          return 'Finish setting up your case first, then try inviting again.';
        }
        return e.message ?? 'This action is not available right now.';
      case 'permission-denied':
        if (msg.contains('attorney')) {
          return 'This account type cannot create that invite.';
        }
        return e.message ?? 'You do not have permission to do this.';
      case 'invalid-argument':
        return e.message ?? 'Some information was invalid. Check and try again.';
      case 'unauthenticated':
        return 'Please sign in again, then try inviting.';
      case 'resource-exhausted':
        return 'Too many invites right now. Wait a moment and try again.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'The server is busy. Check your connection and try again.';
      case 'not-found':
        return 'Invite service is not available. Update the app or try again later.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
