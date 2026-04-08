import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

/// ⭐ CHANGE THIS ONLY
static const String baseUrl = "https://parentledger-api.onrender.com";

static String? token;
static dynamic currentUser;

/// ⭐ HEADERS
static Map<String, String> _headers() {
return {
"Content-Type": "application/json",
"Accept": "application/json",
if (token != null) "Authorization": "Bearer $token",
};
}

/// ⭐ LOGIN
static Future<dynamic> login({
required String email,
required String password,
}) async {

final body = {
"email": email,
"password": password,
};

print("LOGIN BODY:");
print(body);

final res = await http.post(
Uri.parse("$baseUrl/auth/login"),
headers: _headers(),
body: jsonEncode(body),
);

print("LOGIN STATUS: ${res.statusCode}");
print(res.body);

if (res.statusCode == 200) {

final json = jsonDecode(res.body);

/// ⭐ backend may OR may not return token
token =
json["token"] ??
json["accessToken"] ??
json["jwt"];

currentUser = json["user"];

print("TOKEN:");
print(token);

return json;
}

throw Exception("LOGIN FAILED ${res.statusCode}");
}

/// ⭐ HEALTH CHECK
static Future<dynamic> checkHealth() async {

final res = await http.get(
Uri.parse("$baseUrl/health"),
headers: _headers(),
);

print("HEALTH STATUS: ${res.statusCode}");
print(res.body);

if (res.statusCode == 200) {
return jsonDecode(res.body);
}

throw Exception("HEALTH FAILED ${res.statusCode}");
}

/// ⭐ FETCH HISTORY
static Future<dynamic> fetchHistory() async {

final res = await http.get(
Uri.parse("$baseUrl/history"),
headers: _headers(),
);

print("HISTORY STATUS: ${res.statusCode}");
print(res.body);

if (res.statusCode == 200) {
return jsonDecode(res.body);
}

throw Exception("HISTORY FAILED ${res.statusCode}");
}

}
