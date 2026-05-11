import 'dart:developer' as developer;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'invite_callable_utils.dart';
import 'invite_dynamic_link_builder.dart';

/// Secure co-parent invites: UUID token stored in `coparentInvites/{token}` via Cloud Functions.
class CoparentInviteCodeService {
  CoparentInviteCodeService._();

  static final _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static void _rejectBadUniversalLink(String url, String token) {
    final u = Uri.tryParse(url);
    if (u == null) throw StateError('Invalid universal link from server.');
    if (u.hasQuery) {
      throw StateError('Invite links must not use query parameters.');
    }
    final segs = u.pathSegments;
    // Canonical: /invite/{token} — legacy: /invite/coparent/{token}
    var pathToken = '';
    final inviteIx = segs.indexOf('invite');
    if (inviteIx >= 0 && inviteIx + 1 < segs.length) {
      if (segs[inviteIx + 1] == 'coparent' && inviteIx + 2 < segs.length) {
        pathToken = segs[inviteIx + 2];
      } else {
        pathToken = segs[inviteIx + 1];
        if (pathToken == 'attorney' || pathToken == 'coparent') {
          throw StateError('Universal link path must include a token after /invite/…');
        }
      }
    }
    if (pathToken.isEmpty) {
      throw StateError('Universal link path must be /invite/{token} (or legacy /invite/coparent/{token}).');
    }
    if (pathToken != token && Uri.decodeComponent(pathToken) != token) {
      throw StateError('Token mismatch in universal link path.');
    }
  }

  static void _rejectBadDeepLink(String deepLink, String token) {
    final u = Uri.tryParse(deepLink);
    if (u == null || u.scheme.toLowerCase() != 'parentledger') {
      throw StateError('Invite generation failed: invalid deep link.');
    }
    if (u.host.toLowerCase() != 'invite') {
      throw StateError('Invite generation failed: deep link must use host "invite".');
    }
    final segs = u.pathSegments;
    // parentledger://invite/{token} or parentledger://invite/coparent/{token}
    if (segs.isEmpty) {
      throw StateError('Invite generation failed: invalid deep link.');
    }
    var pathToken = '';
    if (segs[0] == 'coparent' && segs.length >= 2) {
      pathToken = segs[1];
    } else if (segs[0] != 'attorney') {
      pathToken = segs[0];
    }
    if (pathToken.isEmpty ||
        (pathToken != token && Uri.decodeComponent(pathToken) != token)) {
      throw StateError('Invite generation failed: invalid deep link.');
    }
  }

  /// Creates a new pending invite; returns HTTPS path URL + native deep link (no query params).
  static Future<CoparentInviteLinkResult> createInviteCode() async {
    final callable = _functions.httpsCallable(
      'createCoparentInviteCode',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    late final Map<String, dynamic> map;
    try {
      final result = await callable.call(<String, dynamic>{});
      map = InviteCallableUtils.normalizeData(result.data);
    } on FirebaseFunctionsException catch (e, st) {
      developer.log(
        'createCoparentInviteCode failed ${e.code} ${e.message}',
        name: 'InviteFlow',
        error: e,
        stackTrace: st,
      );
      throw Exception(InviteCallableUtils.userMessageFor(e));
    }
    if (map['success'] == false) {
      developer.log(
        'createCoparentInviteCode success=false payload=$map',
        name: 'InviteFlow',
      );
      throw Exception(
        map['message']?.toString().trim().isNotEmpty == true
            ? map['message'].toString().trim()
            : 'We could not generate an invite link. Please try again.',
      );
    }
    final token = InviteCallableUtils.pickInviteToken(map);
    if (token == null || token.isEmpty) {
      developer.log(
        'createCoparentInviteCode missing token keys=${map.keys.toList()}',
        name: 'InviteFlow',
      );
      throw Exception(
        'We could not generate an invite link. Please check your connection '
        'and try again. If this keeps happening, update the app.',
      );
    }

    final universalLinkRaw =
        (map['universalLink'] ?? map['universalUrl'])?.toString().trim() ?? '';
    final deepLinkRaw =
        (map['deepLink'] ?? map['appDeepLink'])?.toString().trim() ?? '';

    final universalLink = universalLinkRaw.isNotEmpty
        ? universalLinkRaw
        : InviteDynamicLinkBuilder.universalCoparentInviteUrl(token).toString();
    final deepLink = deepLinkRaw.isNotEmpty
        ? deepLinkRaw
        : 'parentledger://invite/${Uri.encodeComponent(token)}';

    _rejectBadUniversalLink(universalLink, token);
    _rejectBadDeepLink(deepLink, token);

    // ignore: avoid_print
    print('Invite token: $token');
    // ignore: avoid_print
    print('Universal link: $universalLink');

    return CoparentInviteLinkResult(
      token: token,
      universalLink: universalLink,
      deepLink: deepLink,
      expiresAtIso: map['expiresAt']?.toString(),
    );
  }

  /// Legacy short codes (`coparentInviteCodes`) — manual entry fallback only.
  static Future<AcceptCoparentCodeResult> acceptCode(String rawCode) async {
    final normalized =
        rawCode.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalized.length < 6 || normalized.length > 8) {
      throw ArgumentError('Enter the invite code (6–8 characters).');
    }
    final callable = _functions.httpsCallable(
      'acceptCoparentInviteCode',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final result = await callable.call(<String, dynamic>{'code': normalized});
    final map = InviteCallableUtils.normalizeData(result.data);
    return AcceptCoparentCodeResult(
      ok: map['ok'] == true,
      alreadyMember: map['alreadyMember'] == true,
      caseId: map['caseId']?.toString(),
    );
  }

  /// Share body uses [CoparentInviteLinkResult.universalLink] only (single HTTPS URL).
  static String shareMessageForInviter({
    required String inviterFirstName,
    required CoparentInviteLinkResult invite,
  }) {
    final name =
        inviterFirstName.trim().isEmpty ? 'A parent' : inviterFirstName.trim();
    return '$name invited you to connect on ParentLedger.\n'
        'Open this secure invite to link your co-parenting workspace.\n\n'
        '${invite.universalLink}';
  }
}

@immutable
class CoparentInviteLinkResult {
  const CoparentInviteLinkResult({
    required this.token,
    required this.universalLink,
    required this.deepLink,
    this.expiresAtIso,
  });

  final String token;

  /// `https://parentledger.org/invite/{token}` — Universal Links / App Links.
  final String universalLink;

  /// `parentledger://invite/{token}`
  final String deepLink;

  final String? expiresAtIso;
}

@immutable
class AcceptCoparentCodeResult {
  const AcceptCoparentCodeResult({
    required this.ok,
    this.alreadyMember = false,
    this.caseId,
  });

  final bool ok;
  final bool alreadyMember;
  final String? caseId;
}
