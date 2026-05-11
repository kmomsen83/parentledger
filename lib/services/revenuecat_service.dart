import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'crashlytics_service.dart';

class RevenueCatService {
  RevenueCatService._();

  /// Default **public** SDK key (Google Play). Override for App Store / CI:
  /// `--dart-define=REVENUECAT_PUBLIC_API_KEY=appl_xxx` (iOS) or `test_xxx`.
  static const String _defaultGooglePublicApiKey =
      'goog_KhrJyrBVPbCrGjSRqdJSGBuXSvR';

  static String get apiKey {
    const k = String.fromEnvironment('REVENUECAT_PUBLIC_API_KEY');
    if (k.isNotEmpty) {
      return k;
    }
    return _defaultGooglePublicApiKey;
  }

  static const String proEntitlementId = 'ParentLedger Pro';
  static const String yearlyProductId = 'parentledger_yearly';
  static const String monthlyProductId = 'parentledger_monthly';

  static bool _configured = false;

  static Future<void> configure() async {
    if (_configured) return;
    // Verbose `[Purchases] - DEBUG` spam (e.g. on every rebuild / IME) obscures real issues.
    // Use LogLevel.debug only when diagnosing billing: `--dart-define=REVENUECAT_VERBOSE_LOGS=true`
    const verbose = bool.fromEnvironment('REVENUECAT_VERBOSE_LOGS');
    await Purchases.setLogLevel(
      kDebugMode && verbose ? LogLevel.debug : LogLevel.warn,
    );
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _configured = true;
    if (kReleaseMode &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        apiKey.startsWith('goog_')) {
      debugPrint(
        '[RevenueCatService] iOS release build is using the Play default SDK key. '
        'Set --dart-define=REVENUECAT_PUBLIC_API_KEY=appl_… for App Store.',
      );
    }
  }

  static Future<void> logIn(String appUserId) async {
    await configure();
    await Purchases.logIn(appUserId);
  }

  static Future<void> logOut() async {
    await configure();
    await Purchases.logOut();
  }

  static Future<CustomerInfo> customerInfo() async {
    await configure();
    return Purchases.getCustomerInfo();
  }

  static Future<bool> hasProEntitlement() async {
    final info = await customerInfo();
    return info.entitlements.active.containsKey(proEntitlementId);
  }

  static Future<EntitlementInfo?> proEntitlementDetails() async {
    try {
      final info = await customerInfo();
      return info.entitlements.all[proEntitlementId] ??
          info.entitlements.active[proEntitlementId];
    } catch (_) {
      return null;
    }
  }

  static Future<int?> trialDaysRemaining() async {
    final ent = await proEntitlementDetails();
    if (ent == null || !ent.isActive) return null;
    if (ent.periodType != PeriodType.trial) return null;
    final expStr = ent.expirationDate;
    if (expStr == null || expStr.isEmpty) return null;
    try {
      final exp = DateTime.parse(expStr).toUtc();
      final now = DateTime.now().toUtc();
      final remaining = exp.difference(now);
      if (remaining.isNegative) return 0;
      return remaining.inDays;
    } catch (_) {
      return null;
    }
  }

  static Future<({Package? monthly, Package? yearly})> loadPackages() async {
    await configure();
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) {
      return (monthly: null, yearly: null);
    }

    Package? monthly;
    Package? yearly;

    for (final pkg in current.availablePackages) {
      final id = pkg.storeProduct.identifier;
      if (id == monthlyProductId) {
        monthly = pkg;
      }
      if (id == yearlyProductId) {
        yearly = pkg;
      }
    }

    monthly ??= current.monthly;
    yearly ??= current.annual;

    return (monthly: monthly, yearly: yearly);
  }

  static Future<PaywallResult> presentPaywallIfNeeded() async {
    await configure();
    return RevenueCatUI.presentPaywallIfNeeded(proEntitlementId);
  }

  static Future<PaywallResult> presentPaywall() async {
    await configure();
    return RevenueCatUI.presentPaywall();
  }

  static Future<bool> presentCustomerCenter() async {
    await configure();
    try {
      await RevenueCatUI.presentCustomerCenter();
      return true;
    } catch (e, st) {
      await CrashlyticsService.recordError(
        e,
        st,
        reason: 'presentCustomerCenter',
      );
      return false;
    }
  }
}
