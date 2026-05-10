import 'package:flutter/foundation.dart';

/// Temporary startup tracing — remove or set false when debugging is done.
const bool kStartupDiagEnabled = true;

void startupDiag(String phase, [Object? detail]) {
  if (!kDebugMode || !kStartupDiagEnabled) return;
  if (detail != null) {
    debugPrint('[StartupDiag] $phase → $detail');
  } else {
    debugPrint('[StartupDiag] $phase');
  }
}
