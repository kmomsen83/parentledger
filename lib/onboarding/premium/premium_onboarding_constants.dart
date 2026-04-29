import 'package:flutter/material.dart';

/// Tokens for the premium pre-auth onboarding (financial + legal tone).
abstract final class PremiumOnboardingTokens {
  static const Color gradientTop = Color(0xff0f1c35);
  static const Color gradientMid = Color(0xff111f3c);
  static const Color gradientBottom = Color(0xff060b18);

  static const Color textPrimary = Color(0xfff8fafc);
  static const Color textSecondary = Color(0xff94a3b8);

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientTop, gradientMid, gradientBottom],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xff4f7cff), Color(0xff76c3ff)],
  );

  static List<BoxShadow> ctaGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.42),
          blurRadius: 28,
          spreadRadius: -6,
          offset: const Offset(0, 12),
        ),
      ];

  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: 28, vertical: 24);

  static TextStyle headline(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.4,
            color: textPrimary,
            fontSize: 28,
          ) ??
      const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.4,
        color: textPrimary,
      );

  static TextStyle subtitle(BuildContext context) => TextStyle(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: textSecondary.withValues(alpha: 0.92),
      );
}
