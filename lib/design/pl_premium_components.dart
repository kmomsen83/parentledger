import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design.dart';

/// Primary gradient CTA — use for high-trust actions (invite, continue setup).
class PLPrimaryButton extends StatelessWidget {
  const PLPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.minimumHeight = 54,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double minimumHeight;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final glow = PLDesign.primary.withValues(alpha: 0.35);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && onPressed != null
            ? () {
                HapticFeedback.lightImpact();
                onPressed!();
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.14),
        child: Ink(
          height: minimumHeight,
          decoration: BoxDecoration(
            gradient: enabled ? PLDesign.primaryGradient : null,
            color: enabled ? null : PLDesign.border.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: glow,
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: PLDesign.buttonText.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Frosted glass surface with soft border — dark-mode first.
class PLGlassCard extends StatelessWidget {
  const PLGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Large title + optional eyebrow + supporting subtitle.
class PLSectionHeader extends StatelessWidget {
  const PLSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: PLDesign.dashboardSectionLabel.copyWith(
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            title,
            style: PLDesign.onboardingDisplayTitle.copyWith(
              fontSize: MediaQuery.sizeOf(context).width >= 600 ? 30 : 26,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              subtitle!,
              style: PLDesign.onboardingSupporting,
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact status pill (expiration, badges).
class PLStatusBadge extends StatelessWidget {
  const PLStatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.accent = PLDesign.info,
  });

  final String label;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: PLDesign.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical invite lifecycle — calm checkmarks and labels.
class PLInviteStatus extends StatelessWidget {
  const PLInviteStatus({
    super.key,
    required this.steps,
  });

  final List<PLInviteStatusStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _Row(step: steps[i]),
        ],
      ],
    );
  }
}

class PLInviteStatusStep {
  const PLInviteStatusStep({
    required this.title,
    required this.state,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final PLInviteStepState state;
}

enum PLInviteStepState { pending, active, complete }

class _Row extends StatelessWidget {
  const _Row({required this.step});

  final PLInviteStatusStep step;

  @override
  Widget build(BuildContext context) {
    final done = step.state == PLInviteStepState.complete;
    final active = step.state == PLInviteStepState.active;
    final color = done
        ? PLDesign.success
        : active
            ? PLDesign.primary
            : PLDesign.textMuted.withValues(alpha: 0.45);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? PLDesign.success.withValues(alpha: 0.22)
                : active
                    ? PLDesign.primary.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: color.withValues(alpha: 0.65)),
          ),
          child: done
              ? Icon(Icons.check_rounded, size: 16, color: color)
              : Center(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? PLDesign.primary.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: PLDesign.sectionTitle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: done || active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ),
              if (step.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  step.subtitle!,
                  style: PLDesign.caption.copyWith(
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Shimmer-style loading block (GPU-friendly opacity sweep).
class PLLoadingState extends StatefulWidget {
  const PLLoadingState({
    super.key,
    this.message = 'Loading…',
    this.minHeight = 120,
  });

  final String message;
  final double minHeight;

  @override
  State<PLLoadingState> createState() => _PLLoadingStateState();
}

class _PLLoadingStateState extends State<PLLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.message,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = CurvedAnimation(
            parent: _c,
            curve: Curves.easeInOut,
          ).value;
          return Container(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment(-1.2 + t * 2.4, 0),
                end: Alignment(0.2 + t * 2.4, 0.15),
                colors: [
                  Colors.white.withValues(alpha: 0.04),
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: PLDesign.primary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: PLDesign.onboardingSupporting.copyWith(
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Calm empty / error surface.
class PLEmptyState extends StatelessWidget {
  const PLEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.info_outline_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return PLGlassCard(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: PLDesign.warning.withValues(alpha: 0.9)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: PLDesign.sectionTitle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: PLDesign.onboardingSupporting,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            PLPrimaryButton(
              label: actionLabel!,
              onPressed: onAction,
              minimumHeight: 48,
            ),
          ],
        ],
      ),
    );
  }
}

/// Drag handle + optional top chrome for premium bottom sheets.
class PLPremiumBottomSheet extends StatelessWidget {
  const PLPremiumBottomSheet({
    super.key,
    required this.child,
    this.showHandle = true,
  });

  final Widget child;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHandle) ...[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
        ],
        child,
      ],
    );
  }
}
