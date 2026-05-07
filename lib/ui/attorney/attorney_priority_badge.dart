import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../services/attorney_case_priority.dart';

Color attorneyPriorityAccent(AttorneyCasePriority p) => switch (p) {
      AttorneyCasePriority.stable => PLDesign.success,
      AttorneyCasePriority.needsAttention => PLDesign.warning,
      AttorneyCasePriority.urgent => PLDesign.danger,
    };

/// Counsel triage pill — Stable / Needs Attention / Urgent.
class AttorneyPriorityBadge extends StatelessWidget {
  const AttorneyPriorityBadge({
    super.key,
    required this.priority,
    this.compact = false,
  });

  final AttorneyCasePriority priority;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 11,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: attorneyPriorityAccent(priority).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: attorneyPriorityAccent(priority).withValues(alpha: 0.42),
        ),
      ),
      child: Text(
        priority.label,
        style: PLDesign.caption.copyWith(
          color: attorneyPriorityAccent(priority),
          fontWeight: FontWeight.w800,
          fontSize: compact ? 10.5 : 12,
          letterSpacing: compact ? 0.2 : 0.35,
        ),
      ),
    );
  }
}
