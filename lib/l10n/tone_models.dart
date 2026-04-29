/// UX copy tier for user-facing strings (see `tool/generate_tone_l10n.dart`).
enum UiTone {
  neutral,
  professional,
  legal,
}

extension UiToneSerialization on UiTone {
  /// Persisted value on `users/{uid}.uxTone` and SharedPreferences.
  String get storageName => switch (this) {
        UiTone.neutral => 'neutral',
        UiTone.professional => 'professional',
        UiTone.legal => 'legal',
      };
}

UiTone? parseUiTone(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'neutral':
      return UiTone.neutral;
    case 'professional':
      return UiTone.professional;
    case 'legal':
      return UiTone.legal;
    default:
      return null;
  }
}
