import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../design/design.dart';
import 'dashboard/dashboard_badge.dart';

/// Tiny non-interactive lock + Pro pill for corners (dashboard tiles, limited surfaces).
class ProCornerLockBadge extends StatelessWidget {
  const ProCornerLockBadge({
    super.key,
    this.top = 6,
    this.right = 6,
  });

  final double top;
  final double right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      child: const DashboardBadge(DashboardBadgeKind.pro),
    );
  }
}

/// Corner pill for calendar / read-mostly surfaces (free tier) — matches [DashboardBadge].
class LimitedCornerBadge extends StatelessWidget {
  const LimitedCornerBadge({
    super.key,
    this.top = 6,
    this.right = 6,
  });

  final double top;
  final double right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      child: const DashboardBadge(DashboardBadgeKind.limited),
    );
  }
}

/// Frames locked premium surfaces: full-opacity preview, tiny Pro badge, thin gold edge.
/// Avoids heavy dimming or blur so previews stay legible and persuasive.
class PremiumTeaserShell extends StatelessWidget {
  const PremiumTeaserShell({
    super.key,
    required this.locked,
    required this.child,
    this.showProBadge = true,
    this.borderRadius = 22,
    /// Ultra-light frosted effect on the preview only (keeps text readable).
    this.subtleBlur = false,
  });

  final bool locked;
  final Widget child;
  final bool showProBadge;
  final double borderRadius;
  final bool subtleBlur;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    final radius = BorderRadius.circular(borderRadius);

    Widget preview = child;
    if (subtleBlur) {
      preview = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 0.35, sigmaY: 0.35),
        child: preview,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          preview,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: PLDesign.premiumGold.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          if (showProBadge) const ProCornerLockBadge(),
        ],
      ),
    );
  }
}
