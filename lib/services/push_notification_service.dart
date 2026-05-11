import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers device FCM tokens on `users/{uid}.fcmTokens` for Cloud Functions push delivery.
class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<RemoteMessage>? _foregroundSub;

  static void start() {
    if (kIsWeb) {
      return;
    }
    _foregroundSub ??= FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint(
          '[PushNotificationService] foreground message: '
          '${message.notification?.title}',
        );
      }
    });
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _tokenRefreshSub?.cancel();
        _tokenRefreshSub = null;
        return;
      }
      unawaited(_registerForUser(user.uid));
    });
  }

  static Future<void> _registerForUser(String uid) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (kDebugMode) {
          debugPrint('[PushNotificationService] permission denied');
        }
        return;
      }

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _persistToken(uid, token);
      }

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
        unawaited(_persistToken(uid, newToken));
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PushNotificationService] register failed: $e\n$st');
      }
    }
  }

  static Future<void> _persistToken(String uid, String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty || trimmed.length > 512) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();
    final prev = List<String>.from(snap.data()?['fcmTokens'] ?? const <String>[]);
    final merged = <String>{...prev, trimmed}.toList();
    while (merged.length > 10) {
      merged.removeAt(0);
    }
    await ref.set(<String, dynamic>{'fcmTokens': merged}, SetOptions(merge: true));
  }
}
