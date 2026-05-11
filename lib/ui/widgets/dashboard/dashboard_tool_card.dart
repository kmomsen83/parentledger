import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../premium_locked_tap.dart';
import '../premium_teaser_shell.dart';
import 'dashboard_badge.dart';
import 'dashboard_tool_grid_constants.dart';

/// Single-surface glass tool tile: top-aligned content, optional corner badge overlay, tap polish.
class DashboardToolCard extends StatefulWidget {
  const DashboardToolCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.cornerBadge,
    this.lockedPremium = false,
    this.onLockedTap,
    this.premiumShowProShell = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final DashboardBadgeKind? cornerBadge;
  final bool lockedPremium;
  final VoidCallback? onLockedTap;
  final bool premiumShowProShell;

  @override
  State<DashboardToolCard> createState() => _DashboardToolCardState();
}

class _DashboardToolCardState extends State<DashboardToolCard> {
  bool _hover = false;
  bool _pressed = false;

  static const double _r = DashboardToolGridConstants.cardRadius;

  List<BoxShadow> _outerShadows() {
    final glow = PLDesign.primary.withValues(alpha: _hover ? 0.2 : 0.1);
    return [
      BoxShadow(
        color: glow,
        blurRadius: _hover ? 22 : 16,
        spreadRadius: -3,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.38),
        blurRadius: 12,
        spreadRadius: -2,
        offset: const Offset(0, 5),
      ),
    ];
  }

  BoxDecoration _shadowDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(_r),
      boxShadow: _outerShadows(),
    );
  }

  BoxDecoration _cardDecoration() {
    final edge = _hover
        ? PLDesign.primary.withValues(alpha: 0.42)
        : const Color(0x3387b4ff);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(_r),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xff1a2740).withValues(alpha: 0.94),
          const Color(0xff101a2c),
          const Color(0xff0c1424).withValues(alpha: 0.98),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
      border: Border.all(color: edge, width: 1),
    );
  }

  Widget _buildInner() {
    return Stack(
      clipBehavior: Clip.hardEdge,
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: _cardDecoration()),
        Padding(
          padding: DashboardToolGridConstants.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              SizedBox(
                height: DashboardToolGridConstants.badgeLaneHeight,
                width: double.infinity,
              ),
              Icon(
                widget.icon,
                color: PLDesign.premiumGold.withValues(alpha: 0.9),
                size: DashboardToolGridConstants.iconSize,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      textAlign: TextAlign.left,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PLDesign.body.copyWith(
                        color: PLDesign.textPrimary.withValues(alpha: 0.94),
                        fontWeight: FontWeight.w600,
                        fontSize: DashboardToolGridConstants.titleFontSize,
                        height: DashboardToolGridConstants.titleLineHeight,
                      ),
                    ),
                    if (widget.subtitle != null &&
                        widget.subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle!,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PLDesign.caption.copyWith(
                          fontSize: 10,
                          color: PLDesign.textMuted.withValues(alpha: 0.85),
                          height: 1.15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.cornerBadge != null)
          Positioned(
            top: DashboardToolGridConstants.badgeTop,
            right: DashboardToolGridConstants.badgeRight,
            child: IgnorePointer(
              child: DashboardBadge(widget.cornerBadge!),
            ),
          ),
      ],
    );
  }

  Widget _withDropShadow(Widget child) {
    return DecoratedBox(
      decoration: _shadowDecoration(),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inner = SizedBox.expand(child: _buildInner());

    final Widget body;
    if (widget.lockedPremium) {
      final lockedTap = widget.onLockedTap;
      if (lockedTap == null) {
        if (kDebugMode) {
          debugPrint('DashboardToolCard: lockedPremium without onLockedTap');
        }
        body = _wrapInteractive(inner);
      } else {
        body = PremiumLockedTapHost(
          locked: true,
          onLockedTap: lockedTap,
          child: PremiumTeaserShell(
            locked: true,
            borderRadius: _r,
            showProBadge: widget.premiumShowProShell,
            child: _withDropShadow(inner),
          ),
        );
      }
    } else {
      body = _wrapInteractive(inner);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: body,
    );
  }

  Widget _wrapInteractive(Widget inner) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: _withDropShadow(
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_r),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(_r),
              onTap: widget.onTap,
              splashColor: PLDesign.primary.withValues(alpha: 0.16),
              highlightColor: Colors.white.withValues(alpha: 0.05),
              child: inner,
            ),
          ),
        ),
      ),
    );
  }
}
