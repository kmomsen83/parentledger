import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/invite_links_config.dart';

/// Builds Firebase Dynamic Links via REST (`shortLinks`). Long links MUST use
/// path segments only — never `?id=` / `?code=` / empty query params.
///
/// Requires Dynamic Links enabled for [InviteLinksConfig.uriPrefix] in Firebase console.
class InviteDynamicLinkBuilder {
  InviteDynamicLinkBuilder._();

  static Uri universalCoparentInviteUrl(String token) {
    final encoded = Uri.encodeComponent(token);
    return Uri.parse(
      '${InviteLinksConfig.longLinkOrigin}/invite/$encoded',
    );
  }

  static Uri universalAttorneyInviteUrl(String token) {
    final encoded = Uri.encodeComponent(token);
    return Uri.parse(
      '${InviteLinksConfig.longLinkOrigin}/invite/attorney/$encoded',
    );
  }

  /// Calls `POST .../v1/shortLinks`.
  static Future<Uri> buildShortLink({
    required Uri link,
  }) async {
    final key = InviteLinksConfig.firebaseWebApiKey;
    final endpoint = Uri.parse(
      'https://firebasedynamiclinks.googleapis.com/v1/shortLinks?key=$key',
    );

    final payload = <String, dynamic>{
      'dynamicLinkInfo': <String, dynamic>{
        'domainUriPrefix': InviteLinksConfig.uriPrefix,
        'link': link.toString(),
        'androidInfo': <String, dynamic>{
          'androidPackageName': InviteLinksConfig.androidPackageName,
        },
        'iosInfo': <String, dynamic>{
          'iosBundleId': InviteLinksConfig.iosBundleId,
          'iosAppStoreId': InviteLinksConfig.iosAppStoreId,
        },
      },
      'suffix': <String, String>{
        'option': 'SHORT',
      },
    };

    final resp = await http.post(
      endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200) {
      throw InviteDynamicLinkApiException(
        'Dynamic Links API failed (${resp.statusCode}): ${resp.body}',
      );
    }

    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    final short = map['shortLink'] as String?;
    if (short == null || short.isEmpty) {
      throw const InviteDynamicLinkApiException(
        'Dynamic Links API: missing shortLink in response',
      );
    }
    return Uri.parse(short);
  }

  static Future<Uri> buildShortCoparentInvite(String token) =>
      buildShortLink(link: universalCoparentInviteUrl(token));

  static Future<Uri> buildShortAttorneyInvite(String token) =>
      buildShortLink(link: universalAttorneyInviteUrl(token));
}

class InviteDynamicLinkApiException implements Exception {
  const InviteDynamicLinkApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
