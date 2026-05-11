import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenuecat_service.dart';
import 'server_billing_sync.dart';

/// Client-side hints only. **Billing fields** (`isPremium`, `subscriptionTier`, etc.)
/// are written by the RevenueCat → Firebase **HTTPS webhook** (Admin SDK).
abstract final class SubscriptionUserFirestoreSync {
  static const String entitlementIdField = 'ParentLedger Pro';

  /// After purchase or restore: optional onboarding step only (premium sync is server-side).
  static Future<void> applyProEntitlement({
    required CustomerInfo info,
    String? planKey,
    String? onboardingStep,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final id = RevenueCatService.proEntitlementId;
    final ent = info.entitlements.active[id];
    final active = ent != null;
    if (!active) return;

    if (onboardingStep != null && onboardingStep.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {'onboardingStep': onboardingStep},
            SetOptions(merge: true),
          );
    }

    if (kDebugMode) {
      debugPrint(
        '[SubscriptionUserFirestoreSync] applyProEntitlement (onboarding only) '
        'plan=$planKey — billing via RevenueCat webhook',
      );
    }
  }

  /// When RC reports active trial or expired entitlement that was a trial, mark trial used.
  static Future<void> syncTrialConsumptionFromCustomerInfo(
    CustomerInfo info, {
    Map<String, dynamic>? existingUserData,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final id = RevenueCatService.proEntitlementId;
    final allEnt = info.entitlements.all[id];
    final activeEnt = info.entitlements.active[id];

    final already = existingUserData?['freeTrialUsed'] == true;
    if (already) return;

    var markUsed = false;
    if (activeEnt != null && activeEnt.periodType == PeriodType.trial) {
      markUsed = true;
    }
    // Expired / inactive but last known period was trial (intro consumed).
    if (allEnt != null &&
        !allEnt.isActive &&
        allEnt.periodType == PeriodType.trial) {
      markUsed = true;
    }

    if (!markUsed) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {'freeTrialUsed': true},
      SetOptions(merge: true),
    );
  }

  static Future<void> markFreeTierContinue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await ServerBillingSync.markParentContinueFree();
  }
}
