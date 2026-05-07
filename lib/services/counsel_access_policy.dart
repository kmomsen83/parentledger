import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Soft limits for counsel accounts (free, invite-only). Server rules remain authoritative.
class CounselUploadLimitException implements Exception {
  const CounselUploadLimitException();
}

class CounselAccessPolicy {
  CounselAccessPolicy._();

  /// Non-visible to users — enforced client-side before Storage upload.
  static const int maxAttorneyUploadBytes = 50 * 1024 * 1024;

  /// Minimum time between successful PDF exports for counsel (per device + account).
  static const Duration exportCooldown = Duration(minutes: 2);

  static const String _prefsKeyPrefix = 'counsel_export_ts_';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Remaining wait before another export, or null if allowed.
  static Future<Duration?> exportCooldownRemaining() async {
    final uid = _uid;
    if (uid == null) return null;
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt('$_prefsKeyPrefix$uid');
    if (ms == null) return null;
    final last = DateTime.fromMillisecondsSinceEpoch(ms);
    final end = last.add(exportCooldown);
    final now = DateTime.now();
    if (!now.isBefore(end)) return null;
    return end.difference(now);
  }

  /// Call after a successful export (PDF generated and handed to the user).
  static Future<void> recordExportCompleted() async {
    final uid = _uid;
    if (uid == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(
      '$_prefsKeyPrefix$uid',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static bool fileExceedsAttorneyLimit(int bytes) =>
      bytes > maxAttorneyUploadBytes;
}
