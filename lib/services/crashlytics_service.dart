import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Production error reporting. Collection is disabled in debug to avoid noise.
class CrashlyticsService {
  CrashlyticsService._();

  static Future<void> bootstrap() async {
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  static void log(String message) {
    FirebaseCrashlytics.instance.log(message);
  }

  static Future<void> recordError(
    Object exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    return FirebaseCrashlytics.instance.recordError(
      exception,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }
}
