import 'package:shared_preferences/shared_preferences.dart';

/// Local-only state for the pre-auth “quick onboarding” funnel (value before signup).
abstract final class QuickOnboardingPrefs {
  static const _kCompleted = 'quick_onboarding_completed_v1';
  static const _kStep = 'quick_onboarding_step_v1';
  static const _kRelationship = 'quick_onboarding_relationship_v1';
  static const _kCoparentName = 'quick_onboarding_coparent_name_v1';

  static Future<bool> isCompleted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kCompleted) ?? false;
  }

  static Future<int> savedStep() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kStep) ?? 0;
  }

  static Future<void> persistStep(int step) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kStep, step.clamp(0, 3));
  }

  static Future<void> setRelationship(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRelationship, value);
  }

  static Future<String?> getRelationship() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kRelationship);
  }

  static Future<void> setCoparentName(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCoparentName, value.trim());
  }

  static Future<String?> getCoparentName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kCoparentName);
  }

  /// Call when the user exits the funnel to sign up (after paywall) or after purchase.
  static Future<void> markCompleted() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kCompleted, true);
    await p.remove(_kStep);
  }

  /// Dev / support: reset the guest funnel (e.g. from settings later).
  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kCompleted);
    await p.remove(_kStep);
    await p.remove(_kRelationship);
    await p.remove(_kCoparentName);
  }
}
