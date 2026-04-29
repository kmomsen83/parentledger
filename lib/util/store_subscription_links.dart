import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the platform subscription management page (Play / App Store).
Future<bool> launchManageSubscriptionsInStore() async {
  final uri = manageSubscriptionsUri();
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Uri manageSubscriptionsUri() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return Uri.parse(
        'https://apps.apple.com/account/subscriptions',
      );
    default:
      return Uri.parse(
        'https://play.google.com/store/account/subscriptions',
      );
  }
}
