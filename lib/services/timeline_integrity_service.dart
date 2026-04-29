import 'package:cloud_functions/cloud_functions.dart';

/// Result of [verifyEventChain].
class TimelineChainVerificationResult {
  const TimelineChainVerificationResult._({
    required this.isValid,
    this.message,
  });

  final bool isValid;
  final String? message;

  factory TimelineChainVerificationResult.valid() =>
      const TimelineChainVerificationResult._(isValid: true);

  factory TimelineChainVerificationResult.invalid(String message) =>
      TimelineChainVerificationResult._(isValid: false, message: message);
}

/// Server-side hash-chain verification for `case_events` ([verifyCaseEventChain]).
class TimelineIntegrityService {
  TimelineIntegrityService._();

  static final _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Calls Cloud Function [verifyCaseEventChain] — authoritative chain check.
  static Future<TimelineChainVerificationResult> verifyEventChain(
    String caseId,
  ) async {
    try {
      final callable = _functions.httpsCallable('verifyCaseEventChain');
      final result = await callable.call(<String, dynamic>{'caseId': caseId});
      final map = Map<String, dynamic>.from(
        (result.data as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      );
      final valid = map['valid'] == true;
      if (!valid) {
        return TimelineChainVerificationResult.invalid(
          map['message']?.toString() ??
              'Timeline integrity check failed (possible tampering).',
        );
      }
      return TimelineChainVerificationResult.valid();
    } catch (e) {
      return TimelineChainVerificationResult.invalid(
        'Verification error: $e',
      );
    }
  }
}
