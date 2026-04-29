import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Non-sensitive device context for audit logs (no advertising IDs).
Map<String, dynamic> collectDeviceInfoForAudit() {
  if (kIsWeb) {
    return <String, dynamic>{
      'platform': 'web',
    };
  }
  try {
    return <String, dynamic>{
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
    };
  } catch (_) {
    return <String, dynamic>{'platform': 'unknown'};
  }
}
