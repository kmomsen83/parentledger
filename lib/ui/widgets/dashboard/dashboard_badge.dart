import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// Unified corner badges for dashboard (and shared surfaces like premium teasers).
enum DashboardBadgeKind { pro, limited, brandNew }

/// Fixed-size pill — **Pro**, **Limited**, and **New** share identical outer geometry
/// (width, height, padding, radius, typography scale) for a uniform top-right stack.
class DashboardBadge extends StatelessWidget {
  const DashboardBadge(
    this.kind, {
    super.key,
  });

  final DashboardBadgeKind kind;

  static const double _radius = 999;
  /// Same outer box for every kind (positioning + visual weight).
  static const double _outerWidth = 56;
  static const double _outerHeight = 19;
  static const EdgeInsets _padding = EdgeInsets.symmetric(horizontal: 6, vertical: 2);
  static const double _fontSize = 9;
  static const double _iconSize = 9.5;

  @override
  Widget build(BuildContext context) {
    final borderColor = PLDesign.premiumGold.withValues(alpha: 0.38);
    final bg = Colors.black.withValues(alpha: 0.38);
    final textStyle = PLDesign.caption.copyWith(
      color: PLDesign.premiumChampagne,
      fontWeight: FontWeight.w700,
      fontSize: _fontSize,
      letterSpacing: 0.15,
      height: 1.0,
    );

    late final Widget core;
    switch (kind) {
      case DashboardBadgeKind.pro:
        core = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: _iconSize,
              color: PLDesign.premiumGold.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 2),
            Text('Pro', style: textStyle),
          ],
        );
        break;
      case DashboardBadgeKind.limited:
        core = Text('Limited', style: textStyle);
        break;
      case DashboardBadgeKind.brandNew:
        core = Text(
          'New',
          style: textStyle.copyWith(color: PLDesign.success.withValues(alpha: 0.96)),
        );
        break;
    }

    final border = Border.all(
      color: kind == DashboardBadgeKind.brandNew
          ? PLDesign.success.withValues(alpha: 0.45)
          : borderColor,
      width: 0.75,
    );

    return SizedBox(
      width: _outerWidth,
      height: _outerHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          color: bg,
          border: border,
          boxShadow: [
            BoxShadow(
              color: kind == DashboardBadgeKind.brandNew
                  ? PLDesign.success.withValues(alpha: 0.14)
                  : PLDesign.primary.withValues(alpha: 0.12),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: _padding,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: core,
          ),
        ),
      ),
    );
  }
}
