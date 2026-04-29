import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../paywall_screen.dart';

/// Modal shown when a free user hits a premium-only feature.
Future<void> showUpgradeToUnlockModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          left: 16,
          right: 16,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PLDesign.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PLDesign.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Upgrade to unlock full records',
                  textAlign: TextAlign.center,
                  style: PLDesign.sectionTitle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Access your complete timeline, exports, and court-ready documentation.',
                  textAlign: TextAlign.center,
                  style: PLDesign.body.copyWith(height: 1.45),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: PLDesign.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const PaywallScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Start Free Trial',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Not now',
                    style: PLDesign.caption.copyWith(
                      color: PLDesign.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
