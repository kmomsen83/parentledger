import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/tone_preference.dart';
import 'app_localizations.dart';
import 'tone_models.dart';
import 'tone_string_resolver.g.dart';

/// Localized string for [key] using [TonePreference] (does not subscribe — use in callbacks).
///
/// Optional [toneOverride] for tests or explicit tier.
String t(
  BuildContext context,
  String key, [
  UiTone? toneOverride,
]) {
  final loc = AppLocalizations.of(context);
  final tone = toneOverride ?? context.read<TonePreference>().tone;
  return toneString(loc, key, tone);
}
