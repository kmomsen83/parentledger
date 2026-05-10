import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Production error reporting. Collection is disabled in debug to avoid noise.
class CrashlyticsService {
  CrashlyticsService._();

  static bool _bootstrapped = false;

  static Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
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
