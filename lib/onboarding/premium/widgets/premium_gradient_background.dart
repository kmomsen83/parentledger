import 'dart:ui';

import 'package:flutter/material.dart';

import '../premium_onboarding_constants.dart';

/// Dark blue gradient with optional subtle texture (noise + vignette).
class PremiumGradientBackground extends StatelessWidget {
  const PremiumGradientBackground({
    super.key,
    required this.child,
    this.showTexture = true,
  });

  final Widget child;
  final bool showTexture;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: PremiumOnboardingTokens.screenGradient)),
        if (showTexture)
          Positioned.fill(
            child: CustomPaint(painter: _NoisePainter(opacity: 0.035)),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.55),
                radius: 1.15,
                colors: [
                  Colors.white.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Very subtle film grain–style noise (cheap, no assets).
class _NoisePainter extends CustomPainter {
  _NoisePainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1;

    const step = 6.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        if ((x * 1.7 + y * 2.3).toInt() % 13 == 0) {
          canvas.drawPoints(
            PointMode.points,
            [Offset(x, y)],
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
