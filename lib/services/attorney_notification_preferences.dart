import 'package:shared_preferences/shared_preferences.dart';

/// Local toggles for counsel notification categories (defaults on).
class AttorneyNotificationPreferences {
  AttorneyNotificationPreferences._();

  static const _prefix = 'attorney_notif_cat_';

  static const String catExchange = 'exchange';
  static const String catFlaggedMessage = 'flagged_message';
  static const String catDocument = 'document';
  static const String catActivity = 'activity';

  static const List<String> allCategories = <String>[
    catExchange,
    catFlaggedMessage,
    catDocument,
    catActivity,
  ];

  static Future<Map<String, bool>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, bool>{};
    for (final c in allCategories) {
      out[c] = prefs.getBool('$_prefix$c') ?? true;
    }
    return out;
  }

  static Future<bool> isCategoryEnabled(String category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$category') ?? true;
  }

  static Future<void> setCategoryEnabled(String category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$category', enabled);
  }
}
