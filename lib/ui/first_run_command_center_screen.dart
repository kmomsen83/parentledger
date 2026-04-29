import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';

import '../design/design.dart';
import 'action_inbox_screen.dart';
import 'onboarding_progress_map_screen.dart';
import 'trust_evidence_status_screen.dart';

class FirstRunCommandCenterScreen extends StatelessWidget {
  const FirstRunCommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('welcomeToParentledger')),
        backgroundColor: PLDesign.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: PLDesign.elevatedCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('First 60 seconds', style: PLDesign.sectionTitle),
                const SizedBox(height: 8),
                Text(
                  'Use this quick command center to understand your setup, your action queue, and your trust status.',
                  style: PLDesign.caption.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            context,
            icon: Icons.checklist_rounded,
            title: 'Open Action Inbox',
            subtitle: 'See the 3 next tasks that keep your case moving.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ActionInboxScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            context,
            icon: Icons.route_rounded,
            title: 'View Setup Progress',
            subtitle: 'Understand where you are in onboarding and what is next.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const OnboardingProgressMapScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Check Trust & Evidence',
            subtitle: 'Confirm case linkage and export-readiness status.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TrustEvidenceStatusScreen(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tTone('startUsingDashboard')),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PLDesign.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PLDesign.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: PLDesign.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PLDesign.sectionTitle.copyWith(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: PLDesign.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
