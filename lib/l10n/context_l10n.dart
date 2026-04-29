import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/tone_preference.dart';
import 'app_localizations.dart';
import 'tone_string_resolver.g.dart';

extension ContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Triple-tone localized string; rebuilds when [TonePreference] changes.
  String tTone(String key) {
    final tone = watch<TonePreference>().tone;
    return toneString(l10n, key, tone);
  }

  String tWelcome(String name) {
    final tone = watch<TonePreference>().tone;
    return toneWelcome(l10n, name, tone);
  }

  String tBalanceMinutes(int minutes) {
    final tone = watch<TonePreference>().tone;
    return toneBalanceMinutes(l10n, minutes, tone);
  }
}
