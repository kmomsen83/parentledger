import 'package:flutter/material.dart';

import '../premium_onboarding_constants.dart';

/// Large rounded CTA with blue gradient and soft glow.
class PremiumPrimaryButton extends StatelessWidget {
  const PremiumPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.minimumHeight = 56,
  });

  final String label;
  final VoidCallback onPressed;
  final double minimumHeight;

  @override
  Widget build(BuildContext context) {
    final glowColor = const Color(0xff4f7cff);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        splashColor: Colors.white.withValues(alpha: 0.18),
        child: Ink(
          height: minimumHeight,
          decoration: BoxDecoration(
            gradient: PremiumOnboardingTokens.ctaGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: PremiumOnboardingTokens.ctaGlow(glowColor),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
