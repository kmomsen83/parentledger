import 'package:flutter/material.dart';

/// Subtle press scale before invoking upgrade flow — keeps locked cards visually neutral.
class PremiumLockedTapHost extends StatefulWidget {
  const PremiumLockedTapHost({
    super.key,
    required this.locked,
    required this.onLockedTap,
    required this.child,
  });

  final bool locked;
  final VoidCallback onLockedTap;
  final Widget child;

  @override
  State<PremiumLockedTapHost> createState() => _PremiumLockedTapHostState();
}

class _PremiumLockedTapHostState extends State<PremiumLockedTapHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1, end: 0.988).animate(
    CurvedAnimation(parent: _press, curve: Curves.easeOutCubic),
  );
  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _press.forward();
    await _press.reverse();
    if (!mounted) return;
    widget.onLockedTap();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.locked) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
