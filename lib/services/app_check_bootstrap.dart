import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Initializes App Check once per isolate. Duplicate [activate] calls can trigger
/// Android/iOS `Too many attempts` — when Firestore App Check enforcement is
/// on, that often surfaces as `PERMISSION_DENIED` on reads.
class AppCheckBootstrap {
  AppCheckBootstrap._();

  static bool _activated = false;

  /// Debug: use console-registered debug tokens. Release: Play Integrity + App Attest
  /// with Device Check fallback (iOS).
  static Future<void> activateIfNeeded() async {
    if (_activated) {
      return;
    }
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
      );
      _activated = true;
      if (kDebugMode) {
        debugPrint(
          'App Check: debug providers in debug builds. For release, use Play '
          'Integrity / App Attest; register devices in Firebase Console if needed.',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'Firebase App Check activation failed: $e\n'
          'Hot-restart can trigger "Too many attempts" — wait and retry, or '
          'temporarily relax App Check enforcement in the Firebase Console.\n$st',
        );
      }
    }
  }
}
