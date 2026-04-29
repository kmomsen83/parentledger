import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../providers/case_context.dart';

/// After trial / without membership — clarity positioning (documentation tool).
class SubscriptionAccessReminderBanner extends StatelessWidget {
  const SubscriptionAccessReminderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    if (session.isPremium) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: PLDesign.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: PLDesign.border.withValues(alpha: 0.65)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.description_outlined,
                  color: PLDesign.info.withValues(alpha: 0.9), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Continue your subscription to keep access to your records and tracking.',
                  style: PLDesign.body.copyWith(
                    color: PLDesign.textMuted,
                    height: 1.38,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
