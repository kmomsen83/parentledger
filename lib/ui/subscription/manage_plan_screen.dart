import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/case_context.dart';
import 'parent_ledger_subscription_plans.dart';

/// Profile → full-screen RevenueCat plan management (parents only).
class ManagePlanScreen extends StatelessWidget {
  const ManagePlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    if (session.isAttorney) {
      return Scaffold(
        backgroundColor: const Color(0xff0b1220),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('Plan'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Attorney accounts include professional access at no charge — '
              'no subscription is required.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
          ),
        ),
      );
    }

    return const ParentLedgerSubscriptionPlansScaffold(
      surface: SubscriptionPlansSurface.manage,
    );
  }
}
