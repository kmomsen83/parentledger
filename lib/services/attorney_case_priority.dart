import 'attorney_case_status_service.dart';

/// Counsel-facing triage level for a matter.
enum AttorneyCasePriority {
  stable,
  needsAttention,
  urgent;

  String get label => switch (this) {
        AttorneyCasePriority.stable => 'Stable',
        AttorneyCasePriority.needsAttention => 'Needs Attention',
        AttorneyCasePriority.urgent => 'Urgent',
      };
}

/// Derives priority from custody signals aggregated for counsel dashboards.
class AttorneyCasePriorityResolver {
  AttorneyCasePriorityResolver._();

  static AttorneyCasePriority fromStatus(AttorneyCaseStatus s) {
    final missed = s.missedExchangeCount;
    final flagged = s.flaggedMessageCount;
    final level = (s.riskLevel ?? '').toLowerCase().trim();
    final trend = s.riskTrend.toLowerCase().trim();
    final score = s.riskScore;
    final health = s.healthScore;

    final urgent = missed >= 2 ||
        flagged >= 3 ||
        level == 'high' ||
        (trend == 'up' && score != null && score >= 68) ||
        health < 48;

    if (urgent) return AttorneyCasePriority.urgent;

    final needs = missed >= 1 ||
        flagged >= 1 ||
        level == 'moderate' ||
        (trend == 'up' && score != null && score >= 52) ||
        s.needsAttention ||
        health < 68;

    if (needs) return AttorneyCasePriority.needsAttention;

    return AttorneyCasePriority.stable;
  }

  static int sortRank(AttorneyCasePriority p) => switch (p) {
        AttorneyCasePriority.urgent => 0,
        AttorneyCasePriority.needsAttention => 1,
        AttorneyCasePriority.stable => 2,
      };
}

extension AttorneyCaseStatusPriorityX on AttorneyCaseStatus {
  AttorneyCasePriority get priority =>
      AttorneyCasePriorityResolver.fromStatus(this);
}
