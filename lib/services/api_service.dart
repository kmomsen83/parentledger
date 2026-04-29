import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  /// ⭐ CHANGE THIS ONLY
  static const String baseUrl = "https://parentledger-api.onrender.com";

  static String? token;
  static dynamic currentUser;

  static Map<String, String> _headers() {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  static Future<dynamic> login({
    required String email,
    required String password,
  }) async {
    final body = {
      "email": email,
      "password": password,
    };

    final res = await http
        .post(
          Uri.parse("$baseUrl/auth/login"),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));

    if (kDebugMode) {
      debugPrint('login HTTP ${res.statusCode}');
    }

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;

      token = json["token"] ?? json["accessToken"] ?? json["jwt"];
      currentUser = json["user"];

      return json;
    }

    throw Exception("LOGIN FAILED ${res.statusCode}");
  }

  static Future<dynamic> checkHealth() async {
    final res = await http
        .get(
          Uri.parse("$baseUrl/health"),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 20));

    if (kDebugMode) {
      debugPrint('health HTTP ${res.statusCode}');
    }

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }

    throw Exception("HEALTH FAILED ${res.statusCode}");
  }

  static Future<dynamic> fetchHistory() async {
    final res = await http
        .get(
          Uri.parse("$baseUrl/history"),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 25));

    if (kDebugMode) {
      debugPrint('history HTTP ${res.statusCode}');
    }

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }

    throw Exception("HISTORY FAILED ${res.statusCode}");
  }
}
