import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../onboarding/onboarding_steps.dart';
import '../providers/case_context.dart';

class OnboardingProgressMapScreen extends StatelessWidget {
  const OnboardingProgressMapScreen({super.key});

  int _stepIndex(String step) {
    switch (step) {
      case OnboardingSteps.accountType:
      case OnboardingSteps.roleSelection:
        return 0;
      case OnboardingSteps.newUser:
        return 1;
      case OnboardingSteps.termsPending:
        return 2;
      case OnboardingSteps.profileComplete:
        return 3;
      case OnboardingSteps.coparentInvited:
        return 4;
      case OnboardingSteps.childrenAdded:
        return 5;
      case OnboardingSteps.subscribed:
      case OnboardingSteps.onboardingComplete:
        return 6;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = context.watch<CaseContext>().onboardingStep;
    final current = _stepIndex(step);
    final progress = current / 6;
    final phases = const <String>[
      'Create account',
      'Accept terms',
      'Set up workspace',
      'Invite co-parent',
      'Add children',
      'Finish setup',
    ];

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('setupProgress')),
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
                Text('Setup progress', style: PLDesign.sectionTitle),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).round()}% complete',
                  style: PLDesign.caption,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...phases.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final done = idx < current;
            final active = idx == current;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              leading: Icon(
                done
                    ? Icons.check_circle_rounded
                    : active
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                color: done || active ? PLDesign.success : PLDesign.textMuted,
              ),
              title: Text(
                entry.value,
                style: PLDesign.body.copyWith(
                  color: done || active ? Colors.white : PLDesign.textMuted,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              subtitle: active ? Text(context.tTone('currentStep')) : null,
            );
          }),
        ],
      ),
    );
  }
}
