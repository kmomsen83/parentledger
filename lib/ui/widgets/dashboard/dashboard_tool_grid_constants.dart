import 'package:flutter/widgets.dart';

/// Shared layout tokens for the dashboard tools grid (single source of truth).
abstract final class DashboardToolGridConstants {
  static const double cardRadius = 14;

  /// Equal horizontal and vertical gaps between cells (tight App Store–style rhythm).
  static const double gridGap = 10;

  static const double iconSize = 22;
  static const double titleFontSize = 12.5;
  static const double titleLineHeight = 1.18;

  /// Compact padding; top/right leave room for the fixed-size corner badge.
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(10, 9, 9, 8);

  /// Reserved header band so every card aligns; badge paints in this lane (top-right).
  static const double badgeLaneHeight = 17;

  /// Badge overlay insets (matches visual inset from card edge).
  static const double badgeTop = 6;
  static const double badgeRight = 6;

  /// Breakpoints on grid width (not full screen — parent padding already applied).
  /// Phone-first: 3 columns; tablet 4; desktop 5; large web 6.
  static int crossAxisCountForWidth(double width) {
    if (width < 640) return 3;
    if (width < 960) return 4;
    if (width < 1200) return 5;
    return 6;
  }

  /// Width / height for [GridView] cells — aspect in **[0.85, 0.95]** (slightly tall tiles,
  /// compact on mobile). Per-column tuning keeps tablet/desktop balanced.
  static double childAspectRatioForWidth(double gridWidth) {
    final n = crossAxisCountForWidth(gridWidth);
    final base = switch (n) {
      3 => 0.91,
      4 => 0.90,
      5 => 0.88,
      _ => 0.87,
    };
    return base.clamp(0.85, 0.95);
  }
}
