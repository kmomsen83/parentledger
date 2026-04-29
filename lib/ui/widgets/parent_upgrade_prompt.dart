import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';

import '../../design/design.dart';
import '../paywall_screen.dart';

/// Shown when a parent needs an active Pro subscription for a feature.
Future<void> showParentUpgradePrompt(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: PLDesign.textMuted.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(title, style: PLDesign.heroTitle.copyWith(fontSize: 22)),
            const SizedBox(height: 10),
            Text(
              message,
              style: PLDesign.body.copyWith(
                color: PLDesign.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PaywallScreen(),
                  ),
                );
              },
              child: Text(context.tTone('startFreeTrial')),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tTone('notNow')),
            ),
          ],
        ),
      ),
    ),
  );
}
