import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/case_event.dart';
import 'crashlytics_service.dart';
import 'timeline_actor_resolver.dart';

/// Thrown when the tamper-resistant ledger could not be written after retries.
class EventLoggerException implements Exception {
  EventLoggerException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'EventLoggerException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Single entry point for `case_events` writes through [logCaseEvent] (hashed chain).
/// All methods **throw** on failure — there are no silent failures.
class EventLoggerService {
  EventLoggerService._();

  static final _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static const int _maxAttempts = 3;

  static Duration _backoff(int attempt) =>
      Duration(milliseconds: 350 * (1 << attempt));

  /// Maps app event types to server [LEDGER_EVENT_TYPES] (e.g. `message` → `message_sent`).
  static String _ledgerType(String type) {
    if (type == CaseEventTypes.message) {
      return 'message_sent';
    }
    if (type == 'location_added') {
      return 'status_change';
    }
    return type;
  }

  static Future<void> _callWithRetries(
    Future<void> Function() invoke,
  ) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        await invoke();
        return;
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        if (attempt < _maxAttempts - 1) {
          await Future<void>.delayed(_backoff(attempt));
        }
      }
    }
    await CrashlyticsService.recordError(
      lastError ?? 'unknown',
      lastStack,
      reason: 'logCaseEvent failed after $_maxAttempts attempts',
      fatal: false,
    );
    throw EventLoggerException(
      'Ledger write failed after $_maxAttempts attempts',
      lastError,
    );
  }

  /// Primary API — server appends to `case_events` with chain hash.
  static Future<void> logEvent({
    required String caseId,
    required String type,
    required String title,
    required String description,
    required String actorId,
    required String actorName,
    Map<String, dynamic>? metadata,
  }) async {
    await _callWithRetries(() async {
      final callable = _functions.httpsCallable('logCaseEvent');
      await callable.call(<String, dynamic>{
        'caseId': caseId,
        'type': _ledgerType(type),
        'title': title,
        'description': description,
        'actorId': actorId,
        'actorName': actorName,
        'data': metadata ?? <String, dynamic>{},
      });
    });
  }

  /// Loads display name for [actorId], then logs.
  static Future<void> logEventForActor({
    required String caseId,
    required String type,
    required String title,
    required String description,
    required String actorId,
    Map<String, dynamic>? metadata,
  }) async {
    var name = 'Participant';
    try {
      final a = await TimelineActor.load(actorId);
      name = a.fullName;
    } catch (_) {}
    await logEvent(
      caseId: caseId,
      type: type,
      title: title,
      description: description,
      actorId: actorId,
      actorName: name,
      metadata: metadata,
    );
  }

  static Future<void> logEventForCurrentUser({
    required String caseId,
    required String type,
    required String title,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw EventLoggerException('No authenticated user for ledger write');
    }
    await logEventForActor(
      caseId: caseId,
      type: type,
      title: title,
      description: description,
      actorId: uid,
      metadata: metadata,
    );
  }

  /// Debug-only: prints newest activity for a case (unsorted fetch + local sort).
  static Future<void> printRecentEvents(String caseId, {int limit = 20}) async {
    if (!kDebugMode) return;
    final snap = await FirebaseFirestore.instance
        .collection('case_events')
        .where('caseId', isEqualTo: caseId)
        .limit(100)
        .get();
    final docs = snap.docs.toList();
    docs.sort((a, b) {
      final ma = a.data();
      final mb = b.data();
      final ta = ma['createdAt'] ?? ma['timestamp'];
      final tb = mb['createdAt'] ?? mb['timestamp'];
      final da = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
      final db = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
      return db.compareTo(da);
    });

    // ignore: avoid_print
    debugPrint('—— case_events (latest ${limit.clamp(1, 100)}) caseId=$caseId ——');
    var i = 0;
    for (final d in docs) {
      if (i >= limit) break;
      final m = d.data();
      final ts = m['createdAt'] ?? m['timestamp'];
      final tsStr = ts is Timestamp ? ts.toDate().toIso8601String() : '?';
      // ignore: avoid_print
      debugPrint(
        '#$i  [$tsStr] type=${m['type']} title=${m['title']} actor=${m['actorId'] ?? m['createdBy']}',
      );
      // ignore: avoid_print
      debugPrint(
        '     desc: ${_truncate((m['description'] ?? '').toString(), 120)}',
      );
      i++;
    }
    // ignore: avoid_print
    debugPrint('—— end case_events ——');
  }
}

String _truncate(String s, int max) {
  if (s.length <= max) return s;
  return '${s.substring(0, max)}…';
}
