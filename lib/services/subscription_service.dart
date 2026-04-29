import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crashlytics_service.dart';
import 'revenuecat_service.dart';

/// Product access tier derived **only** from RevenueCat entitlement `isActive`
/// (includes paid and trial while the entitlement is active).
enum AppAccessLevel {
  free,
  premium,
}

/// Central subscription / entitlement state for the app.
///
/// - **Single source** for RevenueCat [CustomerInfo] interpretation.
/// - Does **not** infer access from purchase history — only [EntitlementInfo.isActive].
/// - Cancellation / expiry: when the entitlement becomes inactive, [accessLevel]
///   returns [AppAccessLevel.free] automatically on the next refresh or listener event.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService();

  static const _prefsActive = 'pl_sub_entitlement_active';
  static const _prefsTrial = 'pl_sub_entitlement_trial';
  static const _prefsLevel = 'pl_sub_access_level'; // 'free' | 'premium'

  AppAccessLevel _accessLevel = AppAccessLevel.free;
  bool _isTrial = false;

  /// True while the **pro** entitlement exists in `CustomerInfo.entitlements.active`.
  bool _isActive = false;

  /// Last successful network refresh (for debugging).
  DateTime? _lastRemoteRefreshAt;

  CustomerInfoUpdateListener? _listener;

  AppAccessLevel get accessLevel => _accessLevel;

  /// True when the user is in a trial period for the active entitlement (if known).
  bool get isTrial => _isTrial;

  /// Mirrors RevenueCat: pro entitlement currently active (trial counts as active).
  bool get isActive => _isActive;

  /// Premium feature gate: active pro entitlement.
  bool get isPremiumTier =>
      _accessLevel == AppAccessLevel.premium && _isActive;

  /// Same identifier as [RevenueCatService.proEntitlementId] — use for logs only.
  static String get entitlementId => RevenueCatService.proEntitlementId;

  /// Register real-time updates from RevenueCat.
  void start() {
    if (_listener != null) return;
    _listener = _onCustomerInfoUpdate;
    Purchases.addCustomerInfoUpdateListener(_listener!);
    if (kDebugMode) {
      debugPrint('[SubscriptionService] CustomerInfo listener attached');
    }
  }

  Future<void> refresh() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _lastRemoteRefreshAt = DateTime.now();
      _applyCustomerInfo(info, source: 'refresh');
      await _persistFromCurrentState();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '[SubscriptionService] refresh failed → using cache if present ($e)\n$st',
        );
      }
      await CrashlyticsService.recordError(
        e,
        st,
        reason: 'SubscriptionService.refresh',
      );
      await _restoreFromCache();
    }
  }

  void _onCustomerInfoUpdate(CustomerInfo info) {
    if (kDebugMode) {
      debugPrint('[SubscriptionService] CustomerInfo update (listener)');
    }
    _applyCustomerInfo(info, source: 'listener');
    unawaited(_persistFromCurrentState());
  }

  void _applyCustomerInfo(CustomerInfo info, {required String source}) {
    final id = RevenueCatService.proEntitlementId;
    final EntitlementInfo? ent = info.entitlements.all[id];
    final bool active = ent?.isActive == true;

    _isTrial = ent?.periodType == PeriodType.trial;
    _isActive = active;
    _accessLevel = active ? AppAccessLevel.premium : AppAccessLevel.free;

    if (kDebugMode) {
      debugPrint(
        '[SubscriptionService] apply ($source): entitlement="$id" '
        'active=$active trial=$_isTrial → accessLevel=$_accessLevel',
      );
    }

    notifyListeners();
  }

  /// Call after [Purchases.logOut] so UI shows free until the next login refresh.
  Future<void> handleLoggedOut() async {
    _accessLevel = AppAccessLevel.free;
    _isActive = false;
    _isTrial = false;
    await _persistFromCurrentState();
    if (kDebugMode) {
      debugPrint('[SubscriptionService] handleLoggedOut → free');
    }
    notifyListeners();
  }

  Future<void> _persistFromCurrentState() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_prefsActive, _isActive);
      await p.setBool(_prefsTrial, _isTrial);
      await p.setString(
        _prefsLevel,
        _accessLevel == AppAccessLevel.premium ? 'premium' : 'free',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionService] persist failed: $e');
    }
  }

  Future<void> _restoreFromCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      final cachedActive = p.getBool(_prefsActive);
      if (cachedActive == null) {
        if (kDebugMode) {
          debugPrint('[SubscriptionService] no cache — offline free tier');
        }
        return;
      }

      _isActive = cachedActive;
      _isTrial = p.getBool(_prefsTrial) ?? false;
      final levelStr = p.getString(_prefsLevel);
      _accessLevel = (cachedActive && levelStr == 'premium')
          ? AppAccessLevel.premium
          : AppAccessLevel.free;

      if (kDebugMode) {
        debugPrint(
          '[SubscriptionService] restored from cache: active=$_isActive '
          'trial=$_isTrial access=$_accessLevel (lastRemote=$_lastRemoteRefreshAt)',
        );
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[SubscriptionService] cache read failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Legacy static helpers (call [configure] / [Purchases] through RevenueCat)
  // ---------------------------------------------------------------------------

  static Future<void> initSdkForUser(String userId) async {
    await RevenueCatService.configure();
    await RevenueCatService.logIn(userId);
  }

  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      if (kDebugMode) debugPrint('Offerings load failed');
      return null;
    }
  }

  static Future<Package?> getMonthly() async {
    final pkgs = await RevenueCatService.loadPackages();
    return pkgs.monthly;
  }

  static Future<Package?> getAnnual() async {
    final pkgs = await RevenueCatService.loadPackages();
    return pkgs.yearly;
  }

  static Future<bool> purchase(Package package) async {
    try {
      final result =
          await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo.entitlements.active
          .containsKey(entitlementId);
    } catch (_) {
      if (kDebugMode) debugPrint('Purchase failed');
      return false;
    }
  }

  static Future<bool> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(entitlementId);
    } catch (_) {
      if (kDebugMode) debugPrint('Restore failed');
      return false;
    }
  }

  static Future<void> logoutSdk() async {
    try {
      await RevenueCatService.logOut();
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_listener != null) {
      Purchases.removeCustomerInfoUpdateListener(_listener!);
      _listener = null;
    }
    super.dispose();
  }
}
