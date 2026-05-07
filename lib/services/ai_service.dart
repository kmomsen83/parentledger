import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/user_role.dart';
import 'user_role_service.dart';

/// Secure AI access — all inference runs in Firebase HTTPS callables (no API keys in-app).
class AiService {
  AiService._();

  static const String insightsUnavailableMessage =
      'No insights available yet.';

  /// Shown while dashboard / scan work is in flight (no error).
  static const String insightsGeneratingMessage =
      'Insights are being generated';

  static const String _firestoreCollection = 'ai_cache';

  /// Cache types stored under [ai_cache].
  static const String cacheTypeSummary = 'summary';
  static const String cacheTypeFairness = 'fairness';
  static const String cacheTypeCompliance = 'compliance';
  static const String cacheTypeTone = 'tone';

  static const int _maxAiMessageLines = 20;
  static const Duration _callableTimeout = Duration(seconds: 95);
  static const Duration _assistantCallableTimeout = Duration(seconds: 95);
  static const int _maxRetries = 3;
  static const int _maxJoinedChars = 95000;
  static const Duration _cacheTtl = Duration(minutes: 20);
  static const Duration _rateLimitWindow = Duration(seconds: 5);

  static final Map<String, _CacheBucket<Object>> _cache = {};
  static final Map<String, Future<Object?>> _inFlight = {};
  static final Map<String, DateTime> _featureLastNetworkAt = {};
  static final Map<String, DateTime> _counselCourtSummaryLastAt = {};
  static const Duration _counselCourtSummaryMinGap = Duration(seconds: 45);

  static FirebaseFunctions _functions() =>
      FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-central1');

  static const Duration _toneCallableTimeout = Duration(seconds: 50);

  static String? _currentUid() => FirebaseAuth.instance.currentUser?.uid;

  static String _sha256Hex(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  static String _cacheDocId(String uid, String type, String inputHash) =>
      '${uid}_${type}_$inputHash';

  /// Firestore `ai_cache` document id — matches [firestore.rules] (`{uid}_{type}_{inputHash}`).
  /// Prefer [FirebaseFirestore.instance.collection('ai_cache').doc(...).get()] over collection queries.
  static String aiCacheDocId(String uid, String type, String inputHash) =>
      _cacheDocId(uid, type, inputHash);

  /// Strips transcript prefixes like `[ISO] senderId: body` → body only.
  static String stripMessageLineMetadata(String raw) {
    final t = raw.trim();
    final m = RegExp(r'^\[[^\]]*\]\s*[^:\s]+:\s*(.+)$', dotAll: true).firstMatch(t);
    if (m != null) return m.group(1)!.trim();
    return t;
  }

  /// Last [maxLines] non-empty lines, metadata stripped (for hashing + callables).
  static List<String> normalizeMessagesForAi(
    List<String> messages, {
    int maxLines = _maxAiMessageLines,
  }) {
    final stripped = <String>[];
    for (final raw in messages) {
      final line = stripMessageLineMetadata(raw);
      if (line.isEmpty) continue;
      stripped.add(line);
    }
    if (stripped.length > maxLines) {
      return stripped.sublist(stripped.length - maxLines);
    }
    return stripped;
  }

  static List<String> _finalizeMessagePayload(List<String> norm) {
    if (norm.isEmpty) {
      throw ArgumentError('messages must contain at least one non-empty line.');
    }
    var total = 0;
    final out = <String>[];
    for (var i = norm.length - 1; i >= 0; i--) {
      final line = norm[i];
      final next = total + line.length + (out.isNotEmpty ? 1 : 0);
      if (next > _maxJoinedChars) break;
      out.insert(0, line);
      total = next;
    }
    if (out.isEmpty) {
      final last = norm.last;
      return [last.substring(0, math.min(_maxJoinedChars, last.length))];
    }
    return out;
  }

  static Future<void> _throttleFeature(String feature) async {
    final last = _featureLastNetworkAt[feature];
    final now = DateTime.now();
    if (last != null) {
      final next = last.add(_rateLimitWindow);
      if (now.isBefore(next)) {
        await Future<void>.delayed(next.difference(now));
      }
    }
    _featureLastNetworkAt[feature] = DateTime.now();
  }

  /// Extra spacing for counsel accounts (no subscription; discourages rapid callable churn).
  static Future<void> _throttleCounselCourtSummaryNetwork() async {
    if (await UserRoleService.currentRole() != UserRole.attorney) return;
    final uid = _currentUid();
    if (uid == null) return;
    final last = _counselCourtSummaryLastAt[uid];
    final now = DateTime.now();
    if (last != null) {
      final next = last.add(_counselCourtSummaryMinGap);
      if (now.isBefore(next)) {
        await Future<void>.delayed(next.difference(now));
      }
    }
    _counselCourtSummaryLastAt[uid] = DateTime.now();
  }

  static Future<T> _dedupe<T>(String key, Future<T> Function() run) {
    final hit = _inFlight[key];
    if (hit != null) {
      return hit.then((v) => v as T);
    }
    final fut = (() async {
      try {
        return await run();
      } finally {
        _inFlight.remove(key);
      }
    })();
    _inFlight[key] = fut;
    return fut;
  }

  static Future<Map<String, dynamic>?> _readFirestoreAiCache(
    String uid,
    String type,
    String inputHash,
  ) async {
    try {
      final id = aiCacheDocId(uid, type, inputHash);
      final snap =
          await FirebaseFirestore.instance.collection(_firestoreCollection).doc(id).get();
      if (!snap.exists) return null;
      final data = snap.data();
      final result = data?['result'];
      if (result is Map<String, dynamic>) return Map<String, dynamic>.from(result);
      if (result is Map) return Map<String, dynamic>.from(result);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
    } catch (_) {}
    return null;
  }

  static Future<void> _writeFirestoreAiCache(
    String uid,
    String type,
    String inputHash,
    Map<String, dynamic> result,
  ) async {
    try {
      final id = aiCacheDocId(uid, type, inputHash);
      await FirebaseFirestore.instance.collection(_firestoreCollection).doc(id).set(
        {
          'userId': uid,
          'type': type,
          'inputHash': inputHash,
          'result': result,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  /// Firestore + memory only (no callable). For optimistic UI.
  static Future<Map<String, dynamic>?> peekFairnessCache(String proposal) async {
    final uid = _currentUid();
    if (uid == null) return null;
    final norm = proposal.trim();
    if (norm.length < 6) return null;
    final hash = _sha256Hex(norm);
    final memKey = _hashKey('fair', norm);
    final mem = _cacheGet<Map<String, dynamic>>(memKey);
    if (mem != null) return Map<String, dynamic>.from(mem);
    final fs = await _readFirestoreAiCache(uid, cacheTypeFairness, hash);
    if (fs != null) return Map<String, dynamic>.from(fs);
    return null;
  }

  /// Firestore + memory only (no callable).
  static Future<Map<String, dynamic>?> peekComplianceCache(List<String> messages) async {
    final uid = _currentUid();
    if (uid == null) return null;
    final norm = normalizeMessagesForAi(messages);
    if (norm.isEmpty) return null;
    final lines = _finalizeMessagePayload(norm);
    final payload = lines.join('\n');
    final hash = _sha256Hex(payload);
    final memKey = _hashKey('compliance', payload);
    final mem = _cacheGet<Map<String, dynamic>>(memKey);
    if (mem != null) return Map<String, dynamic>.from(mem);
    final fs = await _readFirestoreAiCache(uid, cacheTypeCompliance, hash);
    if (fs != null) return Map<String, dynamic>.from(fs);
    return null;
  }

  /// Firestore + memory only (no callable).
  static Future<String?> peekCourtSummaryCache(List<String> messages) async {
    final uid = _currentUid();
    if (uid == null) return null;
    final norm = normalizeMessagesForAi(messages);
    if (norm.isEmpty) return null;
    final lines = _finalizeMessagePayload(norm);
    final payload = lines.join('\n');
    final hash = _sha256Hex(payload);
    final memKey = _hashKey('court', payload);
    final mem = _cacheGet<String>(memKey);
    if (mem != null) return mem;
    final fs = await _readFirestoreAiCache(uid, cacheTypeSummary, hash);
    if (fs == null) return null;
    final s = (fs['summary'] ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Server-side tone classification for outbound messages (legalFlag + optional rewrite).
  static Future<Map<String, dynamic>> classifyCoParentMessage(
    String text, {
    bool forceRefresh = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Message text is empty.');
    }
    final uid = _currentUid();
    if (uid == null) {
      throw StateError('Not signed in');
    }
    final inputHash = _sha256Hex(trimmed);
    final memKey = _hashKey('tone', trimmed);
    if (!forceRefresh) {
      final mem = _cacheGet<Map<String, dynamic>>(memKey);
      if (mem != null) return Map<String, dynamic>.from(mem);
      final fs = await _readFirestoreAiCache(uid, cacheTypeTone, inputHash);
      if (fs != null) {
        final n = _normalizeToneClassification(fs);
        _cacheSet(memKey, n);
        return n;
      }
    }

    return _dedupe<Map<String, dynamic>>('tone_$inputHash', () async {
      await _throttleFeature('tone');
      try {
        final data = await _withRetry(() async {
          final callable = _functions().httpsCallable(
            'classifyCoParentMessage',
            options: HttpsCallableOptions(timeout: _toneCallableTimeout),
          );
          final res = await callable.call(<String, dynamic>{'text': trimmed});
          return _asStringKeyedMap(res.data);
        });
        final normalized = _normalizeToneClassification(data);
        _cacheSet(memKey, normalized);
        await _writeFirestoreAiCache(uid, cacheTypeTone, inputHash, normalized);
        return normalized;
      } catch (_) {
        final fs = await _readFirestoreAiCache(uid, cacheTypeTone, inputHash);
        if (fs != null) return _normalizeToneClassification(fs);
        return _normalizeToneClassification(const {});
      }
    });
  }

  /// Calls [generateCourtSummary] with `{ messages: messages }` (trimmed non-empty lines only).
  static Future<String> generateCourtSummary(
    List<String> messages, {
    bool forceRefresh = false,
  }) async {
    final norm = normalizeMessagesForAi(messages);
    if (norm.isEmpty) {
      throw ArgumentError('messages must contain at least one non-empty line.');
    }
    final lines = _finalizeMessagePayload(norm);
    final payload = lines.join('\n');
    final cacheKey = _hashKey('court', payload);
    final inputHash = _sha256Hex(payload);
    final uid = _currentUid();
    if (uid == null) throw StateError('Not signed in');

    if (!forceRefresh) {
      final cached = _cacheGet<String>(cacheKey);
      if (cached != null) return cached;
      final fs = await _readFirestoreAiCache(uid, cacheTypeSummary, inputHash);
      if (fs != null) {
        final s = _clampSummaryBullets((fs['summary'] ?? '').toString().trim());
        if (s.isNotEmpty) {
          _cacheSet(cacheKey, s);
          return s;
        }
      }
    }

    return _dedupe<String>('summary_$inputHash', () async {
      await _throttleCounselCourtSummaryNetwork();
      await _throttleFeature('summary');
      try {
        final data = await _withRetry(() async {
          final callable = _functions().httpsCallable(
            'generateCourtSummary',
            options: HttpsCallableOptions(timeout: _callableTimeout),
          );
          final res = await callable.call(<String, dynamic>{'messages': lines});
          return _asStringKeyedMap(res.data);
        });
        var summary = (data['summary'] ?? '').toString().trim();
        summary = _clampSummaryBullets(summary);
        if (summary.isEmpty) {
          summary = _courtSummarySafeFallback();
        }
        _cacheSet(cacheKey, summary);
        await _writeFirestoreAiCache(uid, cacheTypeSummary, inputHash, {
          'summary': summary,
        });
        return summary;
      } catch (_) {
        final fs = await _readFirestoreAiCache(uid, cacheTypeSummary, inputHash);
        if (fs != null) {
          final s = _clampSummaryBullets((fs['summary'] ?? '').toString().trim());
          if (s.isNotEmpty) {
            _cacheSet(cacheKey, s);
            return s;
          }
        }
        return insightsUnavailableMessage;
      }
    });
  }

  /// Returns `{ score: double, result: fair|unfair|balanced, reasoning: String }`.
  static Future<Map<String, dynamic>> analyzeFairness(
    String proposal, {
    bool forceRefresh = false,
  }) async {
    final trimmed = proposal.trim();
    if (trimmed.length < 6) {
      throw ArgumentError('Proposal text is too short.');
    }
    final uid = _currentUid();
    if (uid == null) throw StateError('Not signed in');
    final inputHash = _sha256Hex(trimmed);
    final cacheKey = _hashKey('fair', trimmed);

    if (!forceRefresh) {
      final hit = _cacheGet<Map<String, dynamic>>(cacheKey);
      if (hit != null) return Map<String, dynamic>.from(hit);
      final fs = await _readFirestoreAiCache(uid, cacheTypeFairness, inputHash);
      if (fs != null) {
        final n = _normalizeFairnessResponse(fs);
        _cacheSet(cacheKey, n);
        return n;
      }
    }

    return _dedupe<Map<String, dynamic>>('fairness_$inputHash', () async {
      await _throttleFeature('fairness');
      try {
        final data = await _withRetry(() async {
          final callable = _functions().httpsCallable(
            'analyzeFairness',
            options: HttpsCallableOptions(timeout: _callableTimeout),
          );
          final res = await callable.call(<String, dynamic>{'proposal': trimmed});
          return _asStringKeyedMap(res.data);
        });
        final normalized = _normalizeFairnessResponse(data);
        _cacheSet(cacheKey, normalized);
        await _writeFirestoreAiCache(uid, cacheTypeFairness, inputHash, normalized);
        return normalized;
      } catch (_) {
        final fs = await _readFirestoreAiCache(uid, cacheTypeFairness, inputHash);
        if (fs != null) {
          final n = _normalizeFairnessResponse(fs);
          _cacheSet(cacheKey, n);
          return n;
        }
        return _fairnessUnavailablePlaceholder();
      }
    });
  }

  /// Returns `{ riskLevel: low|medium|high, issues: List<String> }`.
  /// Unified assistant: app help, case-grounded answers, neutral guidance — intent is inferred server-side.
  static Future<String> askSmartAssistant(
    String question, {
    String? caseId,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('question is empty.');
    }
    final uid = _currentUid();
    if (uid == null) throw StateError('Not signed in');
    final caseKey = (caseId == null || caseId.trim().isEmpty) ? '_' : caseId.trim();
    final dedupeHash = _sha256Hex('$uid::$caseKey::$trimmed');

    return _dedupe<String>('assistant_$dedupeHash', () async {
      await _throttleFeature('assistant');
      final data = await _withRetry(() async {
        final callable = _functions().httpsCallable(
          'smartAssistant',
          options: HttpsCallableOptions(timeout: _assistantCallableTimeout),
        );
        final res = await callable.call(<String, dynamic>{
          'question': trimmed,
          'caseId': caseId ?? '',
        });
        return _asStringKeyedMap(res.data);
      });
      final text = (data['text'] ?? '').toString().trim();
      if (text.isEmpty) {
        throw StateError('Assistant returned no text.');
      }
      return text;
    });
  }

  static Future<Map<String, dynamic>> detectComplianceIssues(
    List<String> messages, {
    bool forceRefresh = false,
  }) async {
    final norm = normalizeMessagesForAi(messages);
    if (norm.isEmpty) {
      return {
        'riskLevel': 'low',
        'issues': <String>[],
        'receivedAt': DateTime.now().toUtc().toIso8601String(),
      };
    }
    final lines = _finalizeMessagePayload(norm);
    final payload = lines.join('\n');
    final uid = _currentUid();
    if (uid == null) throw StateError('Not signed in');
    final inputHash = _sha256Hex(payload);
    final cacheKey = _hashKey('compliance', payload);

    if (!forceRefresh) {
      final hit = _cacheGet<Map<String, dynamic>>(cacheKey);
      if (hit != null) return Map<String, dynamic>.from(hit);
      final fs = await _readFirestoreAiCache(uid, cacheTypeCompliance, inputHash);
      if (fs != null) {
        final n = _normalizeComplianceResponse(fs);
        _cacheSet(cacheKey, n);
        return n;
      }
    }

    return _dedupe<Map<String, dynamic>>('compliance_$inputHash', () async {
      await _throttleFeature('compliance');
      try {
        final data = await _withRetry(() async {
          final callable = _functions().httpsCallable(
            'detectCompliance',
            options: HttpsCallableOptions(timeout: _callableTimeout),
          );
          final res = await callable.call(<String, dynamic>{'messages': lines});
          return _asStringKeyedMap(res.data);
        });
        final normalized = _normalizeComplianceResponse(data);
        _cacheSet(cacheKey, normalized);
        await _writeFirestoreAiCache(uid, cacheTypeCompliance, inputHash, normalized);
        return normalized;
      } catch (_) {
        final fs = await _readFirestoreAiCache(uid, cacheTypeCompliance, inputHash);
        if (fs != null) {
          final n = _normalizeComplianceResponse(fs);
          _cacheSet(cacheKey, n);
          return n;
        }
        return _complianceUnavailablePlaceholder();
      }
    });
  }

  /// Parses JSON from model text; strips markdown fences; returns null on failure.
  static Object? parseJsonSafely(String text) {
    try {
      final cleaned = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(cleaned);
    } catch (_) {
      try {
        final stripped = text
            .replaceAll('```json', '')
            .replaceAll('```JSON', '')
            .replaceAll('```', '')
            .trim();
        final start = stripped.indexOf('{');
        final end = stripped.lastIndexOf('}');
        if (start >= 0 && end > start) {
          return jsonDecode(stripped.substring(start, end + 1));
        }
      } catch (_) {}
      return null;
    }
  }

  static String userFacingMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'deadline-exceeded':
        case 'timeout':
          return 'The AI request timed out. Check your connection and try again.';
        case 'unauthenticated':
          return 'Please sign in again to use AI features.';
        case 'permission-denied':
          return 'You do not have permission to run this analysis.';
        case 'resource-exhausted':
        case 'unavailable':
          return 'AI is temporarily busy. Please wait a moment and try again.';
        case 'invalid-argument':
          return error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : 'Some inputs were invalid. Try again with different text.';
        case 'failed-precondition':
          return 'AI is not configured on the server yet. Ask your administrator to set the Gemini key.';
        default:
          break;
      }
      final m = error.message?.trim();
      if (m != null && m.isNotEmpty) return m;
    }
    if (error is FormatException || error is ArgumentError) {
      final m = error.toString();
      if (m.length > 120) return 'Invalid input or response. Please try again.';
      return m;
    }
    if (error is TimeoutException) {
      return 'The request took too long. Try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  static void clearCache() => _cache.clear();

  static String _clampSummaryBullets(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';
    final bullets = lines
        .where(
          (l) =>
              l.startsWith('-') ||
              l.startsWith('•') ||
              l.startsWith('*') ||
              RegExp(r'^\d+\.').hasMatch(l),
        )
        .toList();
    final pick = bullets.length >= 2 ? bullets : lines;
    if (pick.length <= 5) return pick.join('\n');
    return pick.take(5).join('\n');
  }

  static String _firstSentence(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    final m = RegExp(r'[.!?](\s|$)').firstMatch(t);
    if (m == null) {
      return t.length > 220 ? '${t.substring(0, 220)}…' : t;
    }
    return t.substring(0, m.end).trim();
  }

  static Map<String, dynamic> _fairnessSafeDefault() => {
        'score': 50,
        'result': 'balanced',
        'reasoning': 'Unable to analyze',
        'receivedAt': DateTime.now().toUtc().toIso8601String(),
      };

  static Map<String, dynamic> _fairnessUnavailablePlaceholder() => {
        ..._fairnessSafeDefault(),
        'reasoning': insightsUnavailableMessage,
        '_insightsUnavailable': true,
      };

  static Map<String, dynamic> _normalizeFairnessResponse(Map<String, dynamic> raw) {
    try {
      final result = (raw['result'] ?? '').toString().trim().toLowerCase();
      if (result != 'fair' && result != 'unfair' && result != 'balanced') {
        return _fairnessSafeDefault();
      }

      final reasoning = (raw['reasoning'] ?? raw['explanation'] ?? '')
          .toString()
          .trim();
      final reasoningOut = reasoning.isNotEmpty
          ? _firstSentence(reasoning)
          : 'Unable to analyze';

      var score = (raw['score'] as num?)?.toDouble() ??
          double.tryParse(raw['score']?.toString() ?? '') ??
          double.nan;
      if (score.isNaN || score < 0 || score > 100) {
        score = result == 'fair'
            ? 78
            : result == 'unfair'
                ? 28
                : 55;
      }
      final out = <String, dynamic>{
        'score': score,
        'result': result,
        'reasoning': reasoningOut,
        'receivedAt': DateTime.now().toUtc().toIso8601String(),
      };
      if (raw['_insightsUnavailable'] == true) {
        out['_insightsUnavailable'] = true;
      }
      return out;
    } catch (_) {
      return _fairnessSafeDefault();
    }
  }

  static Map<String, dynamic> _normalizeToneClassification(Map<String, dynamic> raw) {
    try {
      final flag = raw['legalFlag'];
      String? legalFlag;
      if (flag != null) {
        final s = flag.toString().trim().toLowerCase();
        if (s == 'hostile') {
          legalFlag = 'hostile';
        } else if (s == 'non-compliant' || s == 'noncompliant') {
          legalFlag = 'non-compliant';
        }
      }
      final warn = raw['warnBeforeSend'] == true ||
          raw['warnBeforeSend'] == 1 ||
          raw['warnBeforeSend'] == 'true';
      final nr = raw['neutralRewrite'];
      final neutral =
          nr == null ? null : (nr.toString().trim().isEmpty ? null : nr.toString().trim());
      return {
        'legalFlag': legalFlag,
        'warnBeforeSend': warn,
        'neutralRewrite': neutral,
      };
    } catch (_) {
      return {
        'legalFlag': null,
        'warnBeforeSend': false,
        'neutralRewrite': null,
      };
    }
  }

  static Map<String, dynamic> _complianceSafeDefault() => {
        'riskLevel': 'low',
        'issues': <String>[],
        'receivedAt': DateTime.now().toUtc().toIso8601String(),
      };

  static Map<String, dynamic> _complianceUnavailablePlaceholder() => {
        ..._complianceSafeDefault(),
        '_insightsUnavailable': true,
      };

  static Map<String, dynamic> _normalizeComplianceResponse(Map<String, dynamic> raw) {
    try {
      final risk = (raw['riskLevel'] ?? 'low').toString().trim().toLowerCase();
      if (risk != 'low' && risk != 'medium' && risk != 'high') {
        return _complianceSafeDefault();
      }
      final issues = <String>[];
      final list = raw['issues'];
      if (list is List) {
        for (final e in list) {
          final s = e.toString().trim();
          if (s.isNotEmpty) issues.add(s);
        }
      }
      if (issues.isEmpty && raw['violations'] is List) {
        for (final e in raw['violations'] as List) {
          if (e is Map) {
            final t = (e['type'] ?? '').toString().trim();
            final d = (e['description'] ?? '').toString().trim();
            if (t.isNotEmpty && d.isNotEmpty) {
              issues.add('$t: $d');
            }
          }
        }
      }
      final capped = issues.length > 3 ? issues.sublist(0, 3) : issues;
      final out = <String, dynamic>{
        'riskLevel': risk,
        'issues': capped,
        'receivedAt': DateTime.now().toUtc().toIso8601String(),
      };
      if (raw['_insightsUnavailable'] == true) {
        out['_insightsUnavailable'] = true;
      }
      return out;
    } catch (_) {
      return _complianceSafeDefault();
    }
  }

  static Future<Map<String, dynamic>> _withRetry(
    Future<Map<String, dynamic>> Function() run,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await run();
      } catch (e, st) {
        lastError = e;
        if (!_isRetriable(e) || attempt == _maxRetries - 1) {
          Error.throwWithStackTrace(e, st);
        }
        await Future<void>.delayed(Duration(milliseconds: 350 * (1 << attempt)));
      }
    }
    throw lastError ?? StateError('AI call failed');
  }

  static bool _isRetriable(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.code == 'unavailable' ||
          e.code == 'resource-exhausted' ||
          e.code == 'deadline-exceeded';
    }
    return e is TimeoutException;
  }

  static String _courtSummarySafeFallback() =>
      'Unable to generate a summary from the conversation.';

  static Map<String, dynamic> _asStringKeyedMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    if (raw is String) {
      final parsed = parseJsonSafely(raw);
      if (parsed is Map) {
        return parsed.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  static String _hashKey(String prefix, String content) {
    final digest = sha256.convert(utf8.encode(content));
    return '$prefix:${digest.toString()}';
  }

  static T? _cacheGet<T extends Object>(String key) {
    final b = _cache[key];
    if (b == null) return null;
    if (DateTime.now().difference(b.storedAt) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }
    return b.value as T;
  }

  static void _cacheSet<T extends Object>(String key, T value) {
    if (_cache.length > 80) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CacheBucket(value, DateTime.now());
  }
}

class _CacheBucket<T extends Object> {
  _CacheBucket(this.value, this.storedAt);

  final T value;
  final DateTime storedAt;
}
