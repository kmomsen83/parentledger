import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/case_context.dart';
import '../services/subscription_service.dart';
import '../models/timeline_event_model.dart';
import 'subscription_limits.dart';
import '../ui/widgets/premium_upgrade_sheet.dart';

/// Central entitlement checks aligned with [CaseContext.isPremium]
/// (RevenueCat + optional server `users/{uid}.isPremium` + debug override).
///
/// Use [requirePremiumOrPrompt] before exports / analytics / attorney tooling.
bool isPremium(BuildContext context) =>
    context.read<CaseContext>().isPremium;

/// RevenueCat-only tier (ignores Firestore lifetime grants). Prefer [isPremium]
/// for product UX unless you intentionally exclude server-backed premium.
bool isRevenueCatPremium(BuildContext context) =>
    context.read<SubscriptionService>().isPremiumTier;

/// Free-tier timeline: keep newest-first order; hide excess message-like rows.
List<TimelineEventModel> applyFreeTierTimelineFilter(
  List<TimelineEventModel> newestFirst,
  BuildContext context,
) {
  if (isPremium(context)) return newestFirst;
  var messagesShown = 0;
  final out = <TimelineEventModel>[];
  for (final e in newestFirst) {
    if (e.isMessageLike) {
      if (messagesShown >= SubscriptionLimits.freeMaxTimelineMessageEvents) {
        continue;
      }
      messagesShown++;
    }
    out.add(e);
  }
  return out;
}

/// If [guard] is false, shows the premium upgrade sheet and returns false.
Future<bool> requirePremiumOrPrompt(
  BuildContext context, {
  required bool guard,
  DashboardPremiumFeature feature = DashboardPremiumFeature.complianceReports,
}) async {
  if (guard) return true;
  await showPremiumUpgradeSheet(context, feature: feature);
  return false;
}
