import 'dart:async';
import 'dart:developer' as developer;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'invite_service.dart';

/// Invite deep links via [AppLinks]:
/// - `https://parentledger.org/invite/{token}` (canonical co-parent UUID or case-invite id)
/// - `https://parentledger.org/invite/coparent/{token}` (legacy co-parent)
/// - `https://parentledger.org/invite/attorney/{inviteId|token}` (attorney / case invite doc)
/// - `parentledger://invite/{token}` (native scheme)
/// - Optional `page.link` Embedded `link=` (legacy Firebase Dynamic Links)
/// - Legacy `?code=` short codes and `?token=` / `?id=` invites.
class InviteLinkService {
  InviteLinkService._();
  static const String _pendingInviteKey = 'pending_invite_id';
  static const String _pendingInviteTokenKey = 'pending_invite_token';
  static const String _pendingInviteCodeKey = 'pending_invite_code';

  static final ValueNotifier<String?> pendingInviteId =
      ValueNotifier<String?>(null);
  static final ValueNotifier<String?> pendingInviteToken =
      ValueNotifier<String?>(null);
  static final ValueNotifier<String?> pendingInviteCode =
      ValueNotifier<String?>(null);
  static StreamSubscription<Uri?>? _sub;
  static final AppLinks _appLinks = AppLinks();
  static bool _started = false;

  static final RegExp _caseInvitePathTokenRegex = RegExp(r'^[a-zA-Z0-9_-]+$');

  static void _log(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: 'InviteDeepLink', error: error, stackTrace: stackTrace);
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static Future<String?> readInitialInviteId() async {
    try {
      final uri = await _appLinks.getInitialLink();
      return _extractInviteId(_unwrapFirebaseDynamicLink(uri));
    } catch (_) {
      return null;
    }
  }

  static Future<String?> readInitialInviteToken() async {
    try {
      final uri = await _appLinks.getInitialLink();
      return _extractInviteToken(_unwrapFirebaseDynamicLink(uri));
    } catch (_) {
      return null;
    }
  }

  static Future<String?> readInitialInviteCode() async {
    try {
      final uri = await _appLinks.getInitialLink();
      return _extractInviteCode(_unwrapFirebaseDynamicLink(uri));
    } catch (_) {
      return null;
    }
  }

  /// Same contract as `FirebaseDynamicLinks.instance.getInitialLink` → parse `link`.
  static Future<Uri?> getInitialDynamicUri() async {
    try {
      final uri = await _appLinks.getInitialLink();
      return _unwrapFirebaseDynamicLink(uri);
    } catch (_) {
      return null;
    }
  }

  static Future<void> start() async {
    if (_started) return;
    _started = true;

    Uri? norm;
    try {
      final raw = await _appLinks.getInitialLink();
      norm = _unwrapFirebaseDynamicLink(raw);
      if (raw != null) {
        _log('initial link raw=$raw normalized=${norm ?? raw}');
      }
    } catch (e, st) {
      _log('getInitialLink failed', error: e, stackTrace: st);
      norm = null;
    }

    final initialToken = _extractInviteToken(norm);
    final initialCode =
        initialToken == null ? _extractInviteCode(norm) : null;
    final initialId = (initialToken == null && initialCode == null)
        ? _extractInviteId(norm)
        : null;

    if (initialToken != null) {
      _log('queued token invite (priority over code/id)');
      pendingInviteToken.value = initialToken;
      await _persistPendingInviteToken(initialToken);
    } else if (initialCode != null) {
      _log('queued short invite code (no path token)');
      pendingInviteCode.value = initialCode;
      await _persistPendingInviteCode(initialCode);
    } else if (initialId != null) {
      _log('queued legacy invite id');
      pendingInviteId.value = initialId;
      await _persistPendingInvite(initialId);
    } else {
      final persistedCode = await _readPersistedPendingInviteCode();
      final persistedToken = await _readPersistedPendingInviteToken();
      final persisted = await _readPersistedPendingInvite();
      if (persistedToken != null) {
        pendingInviteToken.value = persistedToken;
      } else if (persistedCode != null) {
        pendingInviteCode.value = persistedCode;
      } else if (persisted != null) {
        pendingInviteId.value = persisted;
      }
    }

    _sub = _appLinks.uriLinkStream.listen((uri) {
      final normalized = _unwrapFirebaseDynamicLink(uri);
      _log('uriLinkStream uri=$uri normalized=$normalized');
      final inviteToken = _extractInviteToken(normalized);
      if (inviteToken != null) {
        _log('stream: token=$inviteToken');
        pendingInviteToken.value = inviteToken;
        unawaited(_persistPendingInviteToken(inviteToken));
        return;
      }
      final code = _extractInviteCode(normalized);
      if (code != null) {
        _log('stream: shortCode=$code');
        pendingInviteCode.value = code;
        unawaited(_persistPendingInviteCode(code));
        return;
      }
      final id = _extractInviteId(normalized);
      if (id != null) {
        _log('stream: inviteId=$id');
        pendingInviteId.value = id;
        unawaited(_persistPendingInvite(id));
      }
    }, onError: (Object e, StackTrace st) {
      _log('uriLinkStream error', error: e, stackTrace: st);
    });
  }

  static Uri? _unwrapFirebaseDynamicLink(Uri? uri) {
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host.contains('page.link')) {
      final inner = uri.queryParameters['link'];
      if (inner != null && inner.isNotEmpty) {
        return Uri.tryParse(inner);
      }
    }
    return uri;
  }

  /// Path segments after `/invite/` (HTTPS) or under `parentledger://invite/…` (native).
  static List<String> _normalizedInvitePathParts(Uri uri) {
    if (uri.scheme.toLowerCase() == 'parentledger' &&
        uri.host.toLowerCase() == 'invite') {
      return uri.pathSegments.where((s) => s.isNotEmpty).toList();
    }
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final ix = segs.indexOf('invite');
    if (ix < 0 || ix + 1 >= segs.length) {
      return const [];
    }
    return segs.sublist(ix + 1);
  }

  /// Resolves invite token from path (UUID / Firestore id); attorney & legacy coparent paths included.
  static String? _tokenFromInvitePath(Uri uri) {
    final parts = _normalizedInvitePathParts(uri);
    if (parts.isEmpty) return null;

    if (parts[0] == 'attorney' && parts.length >= 2) {
      final raw = parts[1].trim();
      if (raw.isEmpty || raw.length > 128) return null;
      if (_caseInvitePathTokenRegex.hasMatch(raw)) return raw;
      return null;
    }

    if (parts[0] == 'coparent' && parts.length >= 2) {
      final raw = parts[1].trim();
      if (raw.isEmpty || raw.length > 200) return null;
      if (_uuidRegex.hasMatch(raw)) return raw;
      if (_caseInvitePathTokenRegex.hasMatch(raw)) return raw;
      return null;
    }

    const reserved = {'attorney', 'coparent'};
    final raw = parts[0].trim();
    if (raw.isEmpty || raw.length > 200) return null;
    if (reserved.contains(raw)) return null;
    if (_uuidRegex.hasMatch(raw)) return raw;
    if (_caseInvitePathTokenRegex.hasMatch(raw)) return raw;
    return null;
  }

  static bool _isTrustedInviteHost(String host) {
    switch (host.toLowerCase()) {
      case 'parentledger.org':
      case 'www.parentledger.org':
        return true;
      default:
        return false;
    }
  }

  /// Path/query invite payloads must not be accepted from arbitrary third-party sites
  /// (phishing / token exfiltration). Native app scheme + production domain only.
  static bool _inviteDeepLinkSourceTrusted(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'parentledger' && uri.host.toLowerCase() == 'invite') {
      return true;
    }
    return _isTrustedInviteHost(uri.host);
  }

  static String? _extractInviteId(Uri? uri) {
    if (uri == null) return null;
    if (!_inviteDeepLinkSourceTrusted(uri) && !kDebugMode) return null;
    final id = uri.queryParameters['id']?.trim();
    if (id != null && id.isNotEmpty) return id;
    final invite = uri.queryParameters['inviteId']?.trim();
    if (invite != null && invite.isNotEmpty) return invite;
    return null;
  }

  static String? _extractInviteToken(Uri? uri) {
    if (uri == null) return null;
    if (!_inviteDeepLinkSourceTrusted(uri) && !kDebugMode) return null;
    final fromPath = _tokenFromInvitePath(uri);
    if (fromPath != null) return fromPath;
    final token = uri.queryParameters['token']?.trim();
    if (token != null && token.isNotEmpty && token.length <= 200) {
      return token;
    }
    return null;
  }

  /// Legacy `?code=` short codes on `/invite` (inbound only; outbound shares use path URLs).
  static String? _extractInviteCode(Uri? uri) {
    if (uri == null) return null;
    final raw = uri.queryParameters['code']?.trim();
    if (raw == null || raw.isEmpty) return null;
    final normalized =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (normalized.length < 6 || normalized.length > 8) return null;
    final inviteNativeHost =
        uri.scheme.toLowerCase() == 'parentledger' &&
            uri.host.toLowerCase() == 'invite';
    final trustedHost = _isTrustedInviteHost(uri.host);
    if (trustedHost || inviteNativeHost) {
      return normalized;
    }
    if (kDebugMode) {
      return normalized;
    }
    return null;
  }

  static void consume() {
    unawaited(_clearPersistedPendingInvite());
    unawaited(_clearPersistedPendingInviteToken());
    unawaited(_clearPersistedPendingInviteCode());
    pendingInviteId.value = null;
    pendingInviteToken.value = null;
    pendingInviteCode.value = null;
    InviteService.clearPendingDeepLinkState();
  }

  /// Drains the queued token (HTTPS path, app scheme, or `?token=`) for routing.
  static String? takePendingInviteToken() {
    final t = pendingInviteToken.value;
    if (t == null || t.isEmpty) return null;
    pendingInviteToken.value = null;
    unawaited(_clearPersistedPendingInviteToken());
    InviteService.pendingInviteToken = null;
    return t;
  }

  static String? takePendingInviteCode() {
    final c = pendingInviteCode.value;
    if (c == null || c.isEmpty) return null;
    pendingInviteCode.value = null;
    unawaited(_clearPersistedPendingInviteCode());
    return c;
  }

  static String? takePendingInviteId() {
    final id = pendingInviteId.value;
    if (id == null || id.isEmpty) return null;
    pendingInviteId.value = null;
    unawaited(_clearPersistedPendingInvite());
    InviteService.pendingInviteId = null;
    return id;
  }

  /// Clears only the co-parent code deep link (after successful join).
  static void consumeCoparentCode() {
    unawaited(_clearPersistedPendingInviteCode());
    pendingInviteCode.value = null;
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  static Future<void> _persistPendingInvite(String inviteId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingInviteKey, inviteId);
  }

  static Future<void> _persistPendingInviteToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingInviteTokenKey, token);
  }

  static Future<void> _persistPendingInviteCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingInviteCodeKey, code);
  }

  static Future<String?> _readPersistedPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    final inviteId = prefs.getString(_pendingInviteKey)?.trim();
    if (inviteId == null || inviteId.isEmpty) return null;
    return inviteId;
  }

  static Future<String?> _readPersistedPendingInviteToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_pendingInviteTokenKey)?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<String?> _readPersistedPendingInviteCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pendingInviteCodeKey)?.trim();
    if (code == null || code.isEmpty) return null;
    return code;
  }

  static Future<void> _clearPersistedPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingInviteKey);
  }

  static Future<void> _clearPersistedPendingInviteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingInviteTokenKey);
  }

  static Future<void> _clearPersistedPendingInviteCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingInviteCodeKey);
  }
}
