import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Sends court export text to an attorney or judge via your backend (never opens the device mail app).
///
/// Deploy **`sendCourtDocumentEmail`** (Firebase Callable, region `us-central1`) **or**
/// **`POST ${ApiService.baseUrl}/legal/email-court-document`** with Bearer Firebase ID token.
/// The server should send the actual email (SendGrid, SES, etc.) and set subject/body like
/// “Court document ready — [title]”.
class CourtDocumentEmailService {
  CourtDocumentEmailService._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static const String _httpPath = '/legal/email-court-document';
  static const Duration _timeout = Duration(seconds: 90);

  static Future<void> send({
    required String recipientEmail,
    required String recipientRole,
    required String caseId,
    required String documentTitle,
    required String documentPlainText,
    String? optionalNote,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in to send court documents.');
    }

    final normalizedEmail = recipientEmail.trim().toLowerCase();
    final normalizedNote = optionalNote?.trim() ?? '';
    final fallbackMessage =
        'A court document has been shared with you via ParentLedger.';

    final payload = <String, dynamic>{
      'toEmail': normalizedEmail,
      'subject': 'Court Document from ParentLedger',
      'message': normalizedNote.isNotEmpty ? normalizedNote : fallbackMessage,
      // Keep backward-compatible metadata for optional server consumers.
      'recipientRole': recipientRole,
      'caseId': caseId,
      'documentTitle': documentTitle,
      'documentPlainText': documentPlainText,
      if (normalizedNote.isNotEmpty) 'optionalNote': normalizedNote,
    };

    try {
      final callable = _functions.httpsCallable(
        'sendCourtDocumentEmail',
        options: HttpsCallableOptions(timeout: _timeout),
      );
      await callable.call(payload);
      return;
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'sendCourtDocumentEmail callable: ${e.code} ${e.message}',
        );
      }
      if (_shouldFallbackToHttp(e)) {
        await _sendHttp(user, payload);
        return;
      }
      throw _wrapFunctionsError(e);
    }
  }

  static bool _shouldFallbackToHttp(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'not-found':
      case 'unimplemented':
      case 'unavailable':
      case 'deadline-exceeded':
      case 'internal':
      case 'resource-exhausted':
        return true;
      default:
        return false;
    }
  }

  static Exception _wrapFunctionsError(FirebaseFunctionsException e) {
    if (e.code == 'permission-denied') {
      return Exception('You do not have permission to send this document.');
    }
    if (e.code == 'unauthenticated') {
      return Exception('Session expired. Sign in again.');
    }
    return Exception(e.message ?? 'Could not send email (${e.code}).');
  }

  static Future<void> _sendHttp(User user, Map<String, dynamic> payload) async {
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Could not verify your session.');
    }

    final uri = Uri.parse('${ApiService.baseUrl}$_httpPath');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    var detail = res.body;
    if (detail.length > 200) detail = '${detail.substring(0, 200)}…';

    throw Exception(
      'Email delivery is not available (${res.statusCode}). '
      'Ensure the server route or Cloud Function is deployed. $detail',
    );
  }
}
