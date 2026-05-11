import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/case_context.dart';
import 'dashboard_screen.dart';
import 'subscription/parent_ledger_subscription_plans.dart';

/// Post-onboarding parent subscription paywall ([AppRouter] → [OnboardingSteps.childrenAdded]).
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    if (session.hasFullAccess || session.isAttorney) {
      return const DashboardScreen();
    }
    return const ParentLedgerSubscriptionPlansScaffold(
      surface: SubscriptionPlansSurface.onboarding,
    );
  }
}
