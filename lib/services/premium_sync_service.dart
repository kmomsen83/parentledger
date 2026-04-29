import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Syncs subscription state with your backend so `users/{uid}.isPremium` can be set
/// server-side (Admin SDK / RevenueCat webhook). The app never writes `isPremium` directly.
///
/// Implement `POST ${ApiService.baseUrl}/premium/sync` (or adjust URL) to verify the
/// Firebase ID token and set premium status from RevenueCat or store receipts.
class PremiumSyncService {
  PremiumSyncService._();

  static const String _syncPath = '/premium/sync';

  /// Returns true if the backend acknowledged sync (HTTP 2xx). False is non-fatal:
  /// [CaseContext.refreshPremiumStatus] still reflects RevenueCat entitlements.
  static Future<bool> syncPremiumWithBackend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return false;

      final uri = Uri.parse('${ApiService.baseUrl}$_syncPath');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(<String, dynamic>{
              'uid': user.uid,
            }),
          )
          .timeout(const Duration(seconds: 20));

      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
