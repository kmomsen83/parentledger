import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../design/design.dart';

/// Tiny non-interactive lock + Pro pill for corners (dashboard tiles, limited surfaces).
class ProCornerLockBadge extends StatelessWidget {
  const ProCornerLockBadge({
    super.key,
    this.top = 8,
    this.right = 8,
  });

  final double top;
  final double right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.black.withValues(alpha: 0.38),
          border: Border.all(
            color: PLDesign.premiumGold.withValues(alpha: 0.35),
            width: 0.75,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 11,
              color: PLDesign.premiumGold.withValues(alpha: 0.95),
            ),
            const SizedBox(width: 4),
            Text(
              'Pro',
              style: PLDesign.caption.copyWith(
                color: PLDesign.premiumChampagne,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
                letterSpacing: 0.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corner pill for calendar / read-mostly surfaces (free tier) — matches [ProCornerLockBadge] styling.
class LimitedCornerBadge extends StatelessWidget {
  const LimitedCornerBadge({
    super.key,
    this.top = 7,
    this.right = 7,
  });

  final double top;
  final double right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.black.withValues(alpha: 0.38),
          border: Border.all(
            color: PLDesign.premiumGold.withValues(alpha: 0.35),
            width: 0.75,
          ),
        ),
        child: Text(
          'Limited',
          style: PLDesign.caption.copyWith(
            color: PLDesign.premiumChampagne,
            fontWeight: FontWeight.w700,
            fontSize: 9.5,
            letterSpacing: 0.2,
            height: 1,
          ),
        ),
      ),
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
          if (showProBadge) ProCornerLockBadge(top: 10, right: 10),
        ],
      ),
    );
  }
}
