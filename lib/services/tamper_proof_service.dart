import 'dart:convert';
import 'package:crypto/crypto.dart';

class TamperProofService {
/// Generate SHA256 hash
static String generateHash({
required String userId,
required String type,
required int severity,
required DateTime timestamp,
required String prevHash,
}) {
final raw = "$userId|$type|$severity|${timestamp.toIso8601String()}|$prevHash";
return sha256.convert(utf8.encode(raw)).toString();
}

/// Verify chain integrity
static bool verifyChain(List<Map<String, dynamic>> events) {
for (int i = 1; i < events.length; i++) {
final prev = events[i - 1];
final current = events[i];

final recalculated = generateHash(
userId: current["userId"],
type: current["type"],
severity: current["severity"],
timestamp: current["timestamp"].toDate(),
prevHash: prev["hash"],
);

if (recalculated != current["hash"]) {
return false; // tampering detected
}
}
return true;
}
}
