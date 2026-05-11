import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/premium_feature.dart';
import '../onboarding/onboarding_steps.dart';
import '../providers/case_context.dart';

/// Role-aware entitlement checks — prefer this over scattered
/// `isPremium` / `isAttorney` combinations for product gating.
///
/// **Parents** are monetized via RevenueCat + optional server grants
/// ([CaseContext.isPremium], `accessLevel`).
///
/// **Attorneys** never hit parent paywalls; counsel features use this object
/// to bypass parent-only premium locks.
class EntitlementManager {
  EntitlementManager(this._ctx);

  final CaseContext _ctx;

  factory EntitlementManager.of(BuildContext context) =>
      EntitlementManager(context.read<CaseContext>());

  bool get isAttorney => _ctx.isAttorney;

  /// Parent Pro (subscription / lifetime / server `isPremium`), never true for attorneys.
  bool get hasParentProEntitlement => _ctx.unlockedParentPremiumFeatures;

  /// Counsel workspace OR Parent Pro — use for exports, full timeline, etc.
  bool get hasCounselOrParentProAccess =>
      _ctx.isAttorney || _ctx.unlockedParentPremiumFeatures;

  /// Free-tier caps (timeline messages, etc.) apply only to non-pro **parents**.
  bool get appliesParentFreeTierCaps =>
      !_ctx.isAttorney && !_ctx.unlockedParentPremiumFeatures;

  /// Whether to show the post-onboarding **parent** subscription paywall from routing.
  bool get shouldRouteToParentPaywall =>
      !_ctx.isAttorney &&
      !_ctx.hasFullAccess &&
      _ctx.onboardingStep == OnboardingSteps.childrenAdded;

  /// Typed feature enum for analytics / future per-feature server checks.
  bool canUse(PremiumFeature feature) {
    if (_ctx.isAttorney) return true;
    return _ctx.unlockedParentPremiumFeatures;
  }
}

extension CaseContextEntitlements on CaseContext {
  EntitlementManager get entitlements => EntitlementManager(this);
}
