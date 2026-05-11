import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical `users/{uid}` subscription-related fields (client merge writes).
abstract final class UserSubscriptionFirestore {
  static const String tierFree = 'free';
  static const String tierParentPro = 'parent_pro';
  static const String tierAttorneyPro = 'attorney_pro';

  static Map<String, dynamic> _flagsParentPro() => <String, dynamic>{
        'messagingFull': true,
        'exportsFull': true,
        'reportsFull': true,
        'aiToolsFull': true,
        'timelineHistoryFull': true,
      };

  static Map<String, dynamic> _flagsParentFree() => <String, dynamic>{
        'messagingFull': false,
        'exportsFull': false,
        'reportsFull': false,
        'aiToolsFull': false,
        'timelineHistoryFull': false,
      };

  static Map<String, dynamic> _flagsAttorneyPro() => <String, dynamic>{
        'counselWorkspace': true,
        'messagingFull': true,
        'exportsFull': true,
        'reportsFull': true,
        'aiToolsFull': true,
        'timelineHistoryFull': true,
      };

  /// After attorney account type or counsel onboarding (client-side merges).
  static Map<String, dynamic> attorneyProfessionalAccess() => <String, dynamic>{
        'subscriptionTier': tierAttorneyPro,
        'subscriptionStatus': 'active',
        'accountType': 'attorney',
        'entitlementFlags': _flagsAttorneyPro(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Parent completed paywall purchase or restore (RevenueCat active).
  static Map<String, dynamic> parentProFromStore({
    String? renewalDateIso,
  }) =>
      <String, dynamic>{
        'subscriptionTier': tierParentPro,
        'accountType': 'parent',
        'entitlementFlags': _flagsParentPro(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (renewalDateIso != null && renewalDateIso.isNotEmpty)
          'renewalDate': renewalDateIso,
      };

  /// Parent chose continue free / skip paywall.
  static Map<String, dynamic> parentFreeTier() => <String, dynamic>{
        'subscriptionTier': tierFree,
        'subscriptionStatus': 'free',
        'accountType': 'parent',
        'entitlementFlags': _flagsParentFree(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
