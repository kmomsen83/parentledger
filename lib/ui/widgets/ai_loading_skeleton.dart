import 'package:flutter/material.dart';

import 'package:parentledger/design/design.dart';

/// Lightweight skeleton for AI insight panels (no extra dependencies).
class AiInsightCardSkeleton extends StatefulWidget {
  const AiInsightCardSkeleton({super.key});

  @override
  State<AiInsightCardSkeleton> createState() => _AiInsightCardSkeletonState();
}

class _AiInsightCardSkeletonState extends State<AiInsightCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bone(double w, double h) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Color.lerp(
              PLDesign.border.withValues(alpha: 0.35),
              PLDesign.border.withValues(alpha: 0.65),
              t.value,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _bone(140, 14),
            const Spacer(),
            _bone(72, 12),
          ],
        ),
        const SizedBox(height: 12),
        _bone(double.infinity, 12),
        const SizedBox(height: 8),
        _bone(double.infinity, 12),
        const SizedBox(height: 8),
        _bone(200, 12),
        const SizedBox(height: 14),
        _bone(120, 13),
        const SizedBox(height: 8),
        _bone(double.infinity, 11),
        const SizedBox(height: 6),
        _bone(double.infinity, 11),
      ],
    );
  }
}
