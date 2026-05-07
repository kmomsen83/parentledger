import '../models/case_event.dart';
import '../models/unified_case_event.dart';

/// Aggregated court-facing summary from unified timeline material.
class CaseCourtSummary {
  const CaseCourtSummary({
    required this.caseId,
    required this.stats,
    required this.flags,
    required this.patterns,
  });

  final String caseId;
  final Map<String, dynamic> stats;
  final List<String> flags;
  final List<String> patterns;
}

class SummaryService {
  SummaryService._();

  static const _profanity = ['damn', 'hell', 'shit', 'fuck', 'bitch', 'asshole'];
  static const _aggression = ['hate', 'kill', 'hurt', 'lawyer', 'contempt', 'police'];

  static CaseCourtSummary build({
    required String caseId,
    required List<UnifiedCaseEvent> events,
  }) {
    var messages = 0;
    var expenses = 0;
    var missedExchanges = 0;
    var lateHints = 0;
    final flags = <String>[];
    final patterns = <String>[];

    for (final u in events) {
      final e = u.event;
      final t = e.type.toLowerCase();
      final body = '${e.title} ${e.description}'.toLowerCase();

      if (t.contains('message') || t == CaseEventTypes.message) {
        messages++;
        for (final w in _profanity) {
          if (body.contains(w)) {
            flags.add('profanity_detected');
            break;
          }
        }
        for (final w in _aggression) {
          if (body.contains(w)) {
            flags.add('aggression_keyword');
            break;
          }
        }
      }
      if (e.isExpenseLike) expenses++;
      if (t.contains('missed') || body.contains('missed')) missedExchanges++;
      if (body.contains('late') || body.contains('running late')) lateHints++;
    }

    if (messages > 40) patterns.add('high_message_volume');
    if (missedExchanges > 0) patterns.add('missed_exchange_pattern');
    if (lateHints > 3) patterns.add('lateness_pattern');

    final stats = <String, dynamic>{
      'messageCount': messages,
      'expenseEventCount': expenses,
      'missedExchangeSignals': missedExchanges,
      'lateArrivalSignals': lateHints,
      'totalLedgerEvents': events.length,
    };

    return CaseCourtSummary(
      caseId: caseId,
      stats: stats,
      flags: flags.toSet().toList(),
      patterns: patterns.toSet().toList(),
    );
  }

  static List<UnifiedCaseEvent> chronological(List<UnifiedCaseEvent> events) {
    final copy = [...events]..sort(
        (a, b) => a.event.createdAt.compareTo(b.event.createdAt),
      );
    return copy;
  }
}
