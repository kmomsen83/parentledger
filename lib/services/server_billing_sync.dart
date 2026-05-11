import 'package:cloud_functions/cloud_functions.dart';

/// Server-only billing mutations (Firestore rules block client writes to premium fields).
abstract final class ServerBillingSync {
  static final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<void> markParentContinueFree() async {
    await _fn.httpsCallable('markParentContinueFree').call();
  }

  static Future<void> applyCounselSubscriptionDefaults() async {
    await _fn.httpsCallable('applyCounselSubscriptionDefaults').call();
  }
}
