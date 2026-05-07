import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/tone_preference.dart';
import 'app_localizations.dart';
import 'tone_string_resolver.g.dart';

extension ContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Triple-tone localized string. Uses [read] so this is safe in event handlers
  /// and async code; wrap the subtree in [Consumer]/[Selector] if you need
  /// instant rebuilds when [TonePreference] changes.
  String tTone(String key) {
    final tone = read<TonePreference>().tone;
    return toneString(l10n, key, tone);
  }

  String tWelcome(String name) {
    final tone = read<TonePreference>().tone;
    return toneWelcome(l10n, name, tone);
  }

  String tBalanceMinutes(int minutes) {
    final tone = read<TonePreference>().tone;
    return toneBalanceMinutes(l10n, minutes, tone);
  }

  String tMessagesUnreadCount(int count) {
    final tone = read<TonePreference>().tone;
    return toneMessagesUnreadMany(l10n, count, tone);
  }
}
