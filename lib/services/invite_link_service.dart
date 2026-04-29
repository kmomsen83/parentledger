import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InviteLinkService {
  InviteLinkService._();
  static const String _pendingInviteKey = 'pending_invite_id';
  static const String _pendingInviteTokenKey = 'pending_invite_token';

  static final ValueNotifier<String?> pendingInviteId =
      ValueNotifier<String?>(null);
  static final ValueNotifier<String?> pendingInviteToken =
      ValueNotifier<String?>(null);
  static StreamSubscription<Uri?>? _sub;
  static final AppLinks _appLinks = AppLinks();
  static bool _started = false;

  static Future<String?> readInitialInviteId() async {
    try {
      final uri = await _appLinks.getInitialLink();
      return _extractInviteId(uri);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> readInitialInviteToken() async {
    try {
      final uri = await _appLinks.getInitialLink();
      return _extractInviteToken(uri);
    } catch (_) {
      return null;
    }
  }

  static Future<void> start() async {
    if (_started) return;
    _started = true;

    final initialId = await readInitialInviteId();
    final initialToken = await readInitialInviteToken();
    if (initialToken != null) {
      pendingInviteToken.value = initialToken;
      await _persistPendingInviteToken(initialToken);
    } else if (initialId != null) {
      pendingInviteId.value = initialId;
      await _persistPendingInvite(initialId);
    } else {
      final persisted = await _readPersistedPendingInvite();
      final persistedToken = await _readPersistedPendingInviteToken();
      if (persistedToken != null) {
        pendingInviteToken.value = persistedToken;
      } else if (persisted != null) {
        pendingInviteId.value = persisted;
      }
    }

    _sub = _appLinks.uriLinkStream.listen((uri) {
      final token = _extractInviteToken(uri);
      if (token != null) {
        pendingInviteToken.value = token;
        unawaited(_persistPendingInviteToken(token));
        return;
      }
      final id = _extractInviteId(uri);
      if (id != null) {
        pendingInviteId.value = id;
        unawaited(_persistPendingInvite(id));
      }
    }, onError: (_) {});
  }

  static String? _extractInviteId(Uri? uri) {
    if (uri == null) return null;
    final id = uri.queryParameters['id']?.trim();
    if (id != null && id.isNotEmpty) return id;
    final invite = uri.queryParameters['inviteId']?.trim();
    if (invite != null && invite.isNotEmpty) return invite;
    return null;
  }

  static String? _extractInviteToken(Uri? uri) {
    if (uri == null) return null;
    final token = uri.queryParameters['token']?.trim();
    if (token != null && token.isNotEmpty) return token;
    return null;
  }

  static void consume() {
    unawaited(_clearPersistedPendingInvite());
    unawaited(_clearPersistedPendingInviteToken());
    pendingInviteId.value = null;
    pendingInviteToken.value = null;
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

  static Future<void> _clearPersistedPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingInviteKey);
  }

  static Future<void> _clearPersistedPendingInviteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingInviteTokenKey);
  }
}
