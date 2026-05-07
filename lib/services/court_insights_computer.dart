import 'package:cloud_firestore/cloud_firestore.dart';

import 'case_event_service.dart';
import 'timeline_violation_filter.dart';

/// Deterministic metrics + lexical scans for court-oriented summaries (no UI).
/// Exchange/check-in logic aligned with [CustodyRiskInsightsService].
class CourtInsightsComputer {
  CourtInsightsComputer._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Lightweight profanity / insult lexicon for automated screening counts only.
  static const Set<String> _profanityTokens = {
    'fuck', 'shit', 'damn', 'bitch', 'bastard', 'asshole', 'crap', 'piss',
    'dick', 'cock', 'whore', 'slut',
  };

  static const Set<String> _aggressiveTokens = {
    'hate', 'idiot', 'stupid', 'moron', 'pathetic', 'worthless', 'useless',
    'shut up', 'screw you', 'drop dead', 'loser', 'disgusting', 'filthy',
    'vengeance', 'destroy you',
  };

  static final RegExp _threatPattern = RegExp(
    r"\b(kill\s+you|hurt\s+you|harm\s+you|i'll\s+get\s+you|watch\s+your\s+back|"
    r"you'll\s+pay|revenge|break\s+your|beat\s+you|coming\s+for\s+you)\b",
    caseSensitive: false,
  );

  static bool _dayInRange(DateTime t, DateTime? start, DateTime? end) {
    final d = DateTime(t.year, t.month, t.day);
    if (start != null) {
      final s = DateTime(start.year, start.month, start.day);
      if (d.isBefore(s)) return false;
    }
    if (end != null) {
      final e = DateTime(end.year, end.month, end.day);
      if (d.isAfter(e)) return false;
    }
    return true;
  }

  static List<DateTime> _weekStarts({int weeks = 8}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday as week start
    var cursor = today.subtract(Duration(days: today.weekday - 1));
    final out = <DateTime>[];
    for (var i = weeks - 1; i >= 0; i--) {
      out.add(cursor.subtract(Duration(days: 7 * i)));
    }
    return out;
  }

  static int _weekIndexContaining(DateTime t, List<DateTime> weekStarts) {
    final d = DateTime(t.year, t.month, t.day);
    for (var i = 0; i < weekStarts.length; i++) {
      final start = weekStarts[i];
      final end = start.add(const Duration(days: 7));
      if (!d.isBefore(start) && d.isBefore(end)) return i;
    }
    return -1;
  }

  /// Average milliseconds between a message and the next reply from the other party.
  static double? _avgResponseHours(List<Map<String, dynamic>> messages) {
    if (messages.length < 2) return null;
    final deltas = <double>[];
    for (var i = 0; i < messages.length - 1; i++) {
      final a = messages[i];
      final b = messages[i + 1];
      final sa = (a['senderId'] ?? '').toString();
      final sb = (b['senderId'] ?? '').toString();
      if (sa.isEmpty || sb.isEmpty || sa == sb) continue;
      final ta = a['createdAt'];
      final tb = b['createdAt'];
      if (ta is! Timestamp || tb is! Timestamp) continue;
      final h = tb.toDate().difference(ta.toDate()).inMinutes / 60.0;
      if (h >= 0 && h < 336) deltas.add(h); // ignore gaps > 14d
    }
    if (deltas.isEmpty) return null;
    deltas.sort();
    return deltas.reduce((a, b) => a + b) / deltas.length;
  }

  static Map<String, int> _scanMessageText(String text) {
    final lower = text.toLowerCase();
    final words = lower.split(RegExp(r'\s+'));
    var profanity = 0;
    var aggressive = 0;
    for (final w in words) {
      final t = w.replaceAll(RegExp(r'[^\w]'), '');
      if (t.isEmpty) continue;
      if (_profanityTokens.contains(t)) profanity++;
    }
    for (final phrase in _aggressiveTokens) {
      if (lower.contains(phrase)) aggressive++;
    }
    final threats = _threatPattern.allMatches(text).length;
    return {
      'profanity': profanity,
      'aggressive': aggressive,
      'threats': threats,
    };
  }

  /// Aggregates exchange + check-in + timeline data for the optional calendar range.
  static Future<Map<String, dynamic>> compute({
    required String caseId,
    required List<Map<String, dynamic>> messages,
    DateTime? rangeStartInclusive,
    DateTime? rangeEndInclusive,
  }) async {
    final checkInsSnap = await _db
        .collection('cases')
        .doc(caseId)
        .collection('exchange_checkins')
        .limit(200)
        .get();

    final exchangesSnap = await _db
        .collection('cases')
        .doc(caseId)
        .collection('exchanges')
        .limit(300)
        .get();

    final now = DateTime.now();

    var totalCheckIns = 0;
    var lateCheckIns = 0;
    for (final d in checkInsSnap.docs) {
      final m = d.data();
      final ts = m['createdAt'];
      DateTime? at;
      if (ts is Timestamp) at = ts.toDate();
      if (at != null &&
          !_dayInRange(at, rangeStartInclusive, rangeEndInclusive)) {
        continue;
      }
      totalCheckIns++;
      final timing = (m['arrivalTiming'] ?? '').toString();
      if (timing == 'late' || timing == 'very_late') lateCheckIns++;
    }

    var missedExchanges = 0;
    var completedInRange = 0;
    for (final d in exchangesSnap.docs) {
      final m = d.data();
      final status = (m['status'] ?? '').toString();
      final st = m['scheduledTime'];
      DateTime? scheduled;
      if (st is Timestamp) scheduled = st.toDate();

      if (scheduled != null &&
          !_dayInRange(scheduled, rangeStartInclusive, rangeEndInclusive)) {
        continue;
      }

      if (status == 'completed') {
        completedInRange++;
        continue;
      }
      if (scheduled != null &&
          scheduled.isBefore(now) &&
          status == 'scheduled') {
        missedExchanges++;
      }
    }

    final lateArrivalPercent =
        totalCheckIns == 0 ? 0.0 : (100.0 * lateCheckIns / totalCheckIns);

    final responseHours =
        _avgResponseHours(messages); // messages already range-filtered by caller

    var profanityTotal = 0;
    var aggressiveTotal = 0;
    var threatsTotal = 0;
    for (final m in messages) {
      final text = (m['text'] ?? '').toString();
      if (text.trim().isEmpty) continue;
      final r = _scanMessageText(text);
      profanityTotal += r['profanity']!;
      aggressiveTotal += r['aggressive']!;
      threatsTotal += r['threats']!;
    }

    final events = await CaseEventService.fetchCaseEvents(caseId);
    var violationLike = 0;
    for (final e in events) {
      if (!_dayInRange(
        e.createdAt,
        rangeStartInclusive,
        rangeEndInclusive,
      )) {
        continue;
      }
      if (TimelineViolationFilter.caseEventIsViolation(e)) {
        violationLike++;
      }
    }

    final weekStarts = _weekStarts(weeks: 8);
    final weekly = <Map<String, dynamic>>[];
    for (final ws in weekStarts) {
      weekly.add(<String, dynamic>{
        'weekStart': ws.toIso8601String(),
        'exchangeIssues': 0,
        'messageConductFlags': 0,
        'timelineViolations': 0,
      });
    }

    void bumpWeek(DateTime? t, void Function(Map<String, dynamic> bucket) fn) {
      if (t == null) return;
      final ix = _weekIndexContaining(t, weekStarts);
      if (ix < 0) return;
      fn(weekly[ix]);
    }

    for (final d in checkInsSnap.docs) {
      final m = d.data();
      final ts = m['createdAt'];
      if (ts is! Timestamp) continue;
      final at = ts.toDate();
      final timing = (m['arrivalTiming'] ?? '').toString();
      if (timing == 'late' || timing == 'very_late') {
        bumpWeek(at, (b) {
          b['exchangeIssues'] = (b['exchangeIssues'] as int) + 1;
        });
      }
    }

    for (final e in events) {
      final t = e.createdAt;
      if (e.metadata['eventSubtype'] == 'exchange_missed') {
        bumpWeek(t, (b) {
          b['exchangeIssues'] = (b['exchangeIssues'] as int) + 1;
        });
      }
      if (TimelineViolationFilter.caseEventIsViolation(e)) {
        bumpWeek(t, (b) {
          b['timelineViolations'] = (b['timelineViolations'] as int) + 1;
        });
      }
    }

    for (final m in messages) {
      final ts = m['createdAt'];
      if (ts is! Timestamp) continue;
      final text = (m['text'] ?? '').toString();
      if (text.trim().isEmpty) continue;
      final r = _scanMessageText(text);
      final flags = r['profanity']! + r['aggressive']! + r['threats']!;
      if (flags > 0) {
        bumpWeek(ts.toDate(), (b) {
          b['messageConductFlags'] =
              (b['messageConductFlags'] as int) + flags;
        });
      }
    }

    final narrative = _buildNarrative(
      rangeStart: rangeStartInclusive,
      rangeEnd: rangeEndInclusive,
      violationLike: violationLike,
      lateArrivals: lateCheckIns,
      missedExchanges: missedExchanges,
      profanityHits: profanityTotal,
      aggressiveHits: aggressiveTotal,
      threatHits: threatsTotal,
    );

    return <String, dynamic>{
      'metrics': <String, dynamic>{
        'lateArrivalPercent': lateArrivalPercent.round(),
        'lateCheckIns': lateCheckIns,
        'exchangeCheckInsSampled': totalCheckIns,
        'missedExchanges': missedExchanges,
        'completedExchangesInRange': completedInRange,
        'avgResponseHours':
            responseHours == null ? null : double.parse(responseHours.toStringAsFixed(2)),
        'timelineViolationSignals': violationLike,
      },
      'messageAnalysis': <String, dynamic>{
        'profanitySignals': profanityTotal,
        'aggressiveToneSignals': aggressiveTotal,
        'threatLanguageSignals': threatsTotal,
        'methodNote':
            'Lexical screening for reporting tallies; not a finding of fact.',
      },
      'weeklyTrend': weekly,
      'narrativeParagraph': narrative,
    };
  }

  static String _buildNarrative({
    DateTime? rangeStart,
    DateTime? rangeEnd,
    required int violationLike,
    required int lateArrivals,
    required int missedExchanges,
    required int profanityHits,
    required int aggressiveHits,
    required int threatHits,
  }) {
    final buf = StringBuffer();
    if (rangeStart != null && rangeEnd != null) {
      final a = DateFormatCompat.format(rangeStart);
      final b = DateFormatCompat.format(rangeEnd);
      buf.write('In the period $a through $b, ');
    } else if (rangeStart != null) {
      buf.write('From ${DateFormatCompat.format(rangeStart)} onward, ');
    } else {
      buf.write('In the documented window, ');
    }

    final parts = <String>[];
    if (violationLike > 0) {
      parts.add(
        '${violationLike == 1 ? 'one' : violationLike.toString()} timeline violation signal${violationLike == 1 ? '' : 's'}',
      );
    }
    if (missedExchanges > 0) {
      parts.add(
        '${missedExchanges == 1 ? 'one' : missedExchanges.toString()} missed exchange${missedExchanges == 1 ? '' : 's'}',
      );
    }
    if (lateArrivals > 0) {
      parts.add(
        '${lateArrivals == 1 ? 'one' : lateArrivals.toString()} late arrival check-in${lateArrivals == 1 ? '' : 's'}',
      );
    }
    if (parts.isEmpty) {
      buf.write(
        'no exchange timing exceptions or timeline violation flags were counted in this pull.',
      );
    } else {
      buf.write('there were ');
      buf.write(_englishJoin(parts));
      buf.write('. ');
    }

    final msgParts = <String>[];
    if (profanityHits > 0) {
      msgParts.add(
        '${profanityHits == 1 ? 'one' : profanityHits.toString()} profanity signal${profanityHits == 1 ? '' : 's'}',
      );
    }
    if (aggressiveHits > 0) {
      msgParts.add(
        '$aggressiveHits aggressive-language signal${aggressiveHits == 1 ? '' : 's'}',
      );
    }
    if (threatHits > 0) {
      msgParts.add(
        '${threatHits == 1 ? 'one' : threatHits.toString()} potential threat-language signal${threatHits == 1 ? '' : 's'}',
      );
    }
    if (msgParts.isNotEmpty) {
      buf.write('Screened messages showed ');
      buf.write(_englishJoin(msgParts));
      buf.write('. ');
    }

    buf.write(
      'Figures are derived from stored records; the court draws conclusions.',
    );
    return buf.toString();
  }

  static String _englishJoin(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    return '${items.sublist(0, items.length - 1).join(', ')}, and ${items.last}';
  }
}

/// Avoid importing intl in service layer for simple dates.
class DateFormatCompat {
  static const _months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String format(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';
}
