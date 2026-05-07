import '../firebase_options.dart';

/// Firebase Dynamic Links domain + app association for invite URLs.
///
/// Configure the same **domainUriPrefix** and link patterns in the Firebase
/// console (Dynamic Links). `IOS_APP_STORE_ID` can be overridden at build time:
/// `--dart-define=IOS_APP_STORE_ID=123456789`
class InviteLinksConfig {
  InviteLinksConfig._();

  /// Page-link prefix from Firebase Dynamic Links console.
  static const String uriPrefix = 'https://parentledger.page.link';

  /// Long link host – embedded in the dynamic link; must match console rules.
  static const String longLinkOrigin = 'https://parentledger.org';

  static const String androidPackageName = 'com.parentledger.app';

  /// Must match the iOS bundle used for Dynamic Links / signing.
  static const String iosBundleId = 'com.parentledger.app';

  /// Replace with your App Store numeric ID when published.
  static const String iosAppStoreId = String.fromEnvironment(
    'IOS_APP_STORE_ID',
    defaultValue: 'YOUR_APP_STORE_ID',
  );

  /// Web API key used by the Dynamic Links REST API (`shortLinks` endpoint).
  /// Uses the Firebase Android client key from [DefaultFirebaseOptions].
  static String get firebaseWebApiKey => DefaultFirebaseOptions.android.apiKey;
}
