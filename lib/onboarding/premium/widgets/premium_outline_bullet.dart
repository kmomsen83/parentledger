import 'package:flutter/material.dart';

import '../premium_onboarding_constants.dart';

/// Single line: outline icon + text — no card, no border box.
class PremiumOutlineBullet extends StatelessWidget {
  const PremiumOutlineBullet({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 22,
              color: const Color(0xff7eb6ff).withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 17,
                height: 1.38,
                fontWeight: FontWeight.w500,
                color: PremiumOnboardingTokens.textPrimary.withValues(alpha: 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
