import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/user_role.dart';
import '../services/firestore_fields.dart';
import '../services/invite_service.dart';
import '../services/revenuecat_service.dart';
import '../services/subscription_service.dart';

/// Single source of truth for signed-in user profile, case membership,
/// subscription state, and related Firestore listeners.
///
/// [AppRouter] only reads this; it does not load user/case data itself.
class CaseContext extends ChangeNotifier {
  CaseContext({SubscriptionService? subscriptionService})
      : _subscription = subscriptionService;

  final SubscriptionService? _subscription;

  /// Must match RevenueCat and [PaywallScreen] / paywall checks.
  static const String premiumEntitlementId = 'ParentLedger Pro';

  /// Dev-only: when true, treats user as premium without RevenueCat (never use in release).
  static bool debugPremiumOverride = false;

  User? _user;
  bool get isSignedIn => _user != null;

  Map<String, dynamic> _userData = {};
  bool _userDocExists = false;
  bool get userDocExists => _userDocExists;

  String? caseId;

  /// Case members (see [FirestoreFields.readCaseMemberIds]).
  List<String> memberIds = [];
  List<dynamic> children = [];

  /// True until the first auth emission is processed.
  bool authInitializing = true;

  /// True while waiting for the first user-document snapshot after sign-in.
  bool userDocLoading = true;

  /// True until [refreshPremiumStatus] completes for the current session.
  bool premiumLoading = true;

  /// Case document loading (only relevant when [caseId] is non-null).
  bool caseLoading = false;

  /// RevenueCat entitlement — synced via [SubscriptionService] when provided.
  bool _revenueCatPremium = false;

  /// Effective premium: RevenueCat entitlement, optional Firestore [isPremium]
  /// (server/Admin only — not client-writable), or debug override **in debug builds only**.
  bool get isPremium => (kDebugMode && debugPremiumOverride)
      ? true
      : (_revenueCatPremium || _userData['isPremium'] == true);

  /// RevenueCat entitlement only (no debug override or server grant).
  bool get hasRevenueCatPremium => _revenueCatPremium;

  String get accessLevel => (_userData['accessLevel'] ?? 'free').toString();

  bool get hasFullAccess =>
      accessLevel == 'lifetime' || isPremium || accessLevel == 'subscription';

  /// Parent Pro features: exports without counsel watermark, advanced insights, etc.
  /// Attorneys always use the limited counsel experience regardless of this flag.
  bool get unlockedParentPremiumFeatures => !isAttorney && hasFullAccess;

  String get onboardingStep => _userData['onboardingStep'] as String? ?? '';

  /// Optional UX copy tier: `neutral`, `professional`, or `legal` (`users/{uid}.uxTone`).
  String? get userUxTone => _userData['uxTone'] as String?;

  /// `parent` (default) or `attorney` — stored on `users/{uid}.role`.
  UserRole get userRole => UserRole.fromObject(_userData['role']);

  bool get isAttorney => userRole.isAttorney;

  /// Short given name for greetings (Firestore first, then display name, email).
  String get greetingFirstName {
    final fn = (_userData['firstName'] ?? '').toString().trim();
    if (fn.isNotEmpty) return fn;
    final dn = (_userData['displayName'] ?? '').toString().trim();
    if (dn.isNotEmpty) {
      final first = dn.split(RegExp(r'\s+')).first;
      if (first.isNotEmpty) return first;
    }
    final email = _user?.email?.trim();
    if (email != null && email.contains('@')) {
      final local = email.split('@').first;
      if (local.isNotEmpty) {
        final part = local.split('.').first;
        if (part.length == 1) return part.toUpperCase();
        return '${part[0].toUpperCase()}${part.substring(1)}';
      }
    }
    return 'there';
  }

  /// Ready for [AppRouter] to branch (signed-out is allowed).
  bool get sessionReadyForRouter {
    if (authInitializing) return false;
    if (_user == null) return true;
    return !userDocLoading && !premiumLoading;
  }

  /// Re-run RevenueCat + user doc wait (used by [SessionLoadingGate] retry).
  Future<void> retrySessionLoading() async {
    if (_user == null) return;
    userDocLoading = true;
    premiumLoading = true;
    _notifyListenersAndTrackReady();
    try {
      await _subscribeUserDoc(_user!.uid);
      await refreshPremiumStatus();
    } catch (_) {
      userDocLoading = false;
      premiumLoading = false;
      _notifyListenersAndTrackReady();
    }
  }

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _caseDocSub;

  String? _sessionUid;
  String? _inviteCheckedUid;

  /// Last [sessionReadyForRouter] value after the previous notify (for transition logs).
  bool _lastNotifiedSessionReady = false;
  bool _userDocFirstSnapshotDone = false;

  /// Call once from [ChangeNotifierProvider] create.
  void start() {
    if (kDebugMode) {
      debugPrint(
        '[CaseContext] start() — subscribing to authStateChanges',
      );
    }
    _subscription?.addListener(_onSubscriptionServiceChanged);
    // Session service: not UI.rebuilds — intentional long-lived [listen] (not paired with [StreamBuilder]).
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  void _onSubscriptionServiceChanged() {
    if (_user == null) return;
    _syncRcPremiumFromService();
    _notifyListenersAndTrackReady();
  }

  void _syncRcPremiumFromService() {
    final sub = _subscription;
    if (sub == null) return;
    _revenueCatPremium = sub.isPremiumTier;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  void _notifyListenersAndTrackReady() {
    notifyListeners();
    final ready = sessionReadyForRouter;
    if (ready && !_lastNotifiedSessionReady) {
      _log(
        '[CaseContext] sessionReadyForRouter → true '
        '(signedIn=$isSignedIn, onboardingStep=$onboardingStep, '
        'userDocLoading=$userDocLoading, premiumLoading=$premiumLoading, '
        'isPremium=$isPremium, revenueCatPremium=$_revenueCatPremium)',
      );
    }
    _lastNotifiedSessionReady = ready;
  }

  Future<void> _onAuthChanged(User? user) async {
    _log(
      '[CaseContext] authStateChanges → ${user == null ? "signedOut" : "signedIn"}',
    );
    authInitializing = false;

    if (user == null) {
      await _clearSession();
      _userDocFirstSnapshotDone = false;
      _notifyListenersAndTrackReady();
      return;
    }

    if (_sessionUid == user.uid) {
      return;
    }

    await _clearSession();
    _sessionUid = user.uid;
    _user = user;

    userDocLoading = true;
    premiumLoading = true;
    _userDocFirstSnapshotDone = false;
    _notifyListenersAndTrackReady();

    try {
      try {
        await RevenueCatService.logIn(user.uid);
      } catch (_) {}

      await _ensureUserDoc(user);
      await _subscribeUserDoc(user.uid);
      await refreshPremiumStatus();

      if (_inviteCheckedUid != user.uid) {
        _inviteCheckedUid = user.uid;
        try {
          await InviteService.checkAndAcceptInvite(user);
        } catch (_) {}
      }
    } catch (_, __) {
      _log('CaseContext session attach failed');
      userDocLoading = false;
      premiumLoading = false;
      _notifyListenersAndTrackReady();
    }
  }

  /// Creates a minimal `users/{uid}` doc if missing (client-side; no Cloud Function).
  Future<void> _ensureUserDoc(User user) async {
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = fn.httpsCallable('ensureUserBootstrap');
      await callable.call();
    } catch (e) {
      _log('[CaseContext] _ensureUserDoc failed: $e');
    }
  }

  Future<void> _subscribeUserDoc(String uid) async {
    await _userDocSub?.cancel();
    final first = Completer<void>();
    // App session state — not used with a [StreamBuilder] for the same [snapshots] instance.
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      userDocLoading = false;
      if (!first.isCompleted) {
        first.complete();
      }
      final isFirst = !_userDocFirstSnapshotDone;
      _userDocFirstSnapshotDone = true;
      _log(
        '[CaseContext] user doc snapshot '
        '(${isFirst ? "initial" : "update"}, exists=${snap.exists}, '
        'path=${snap.reference.path})',
      );
      if (!snap.exists) {
        _userDocExists = false;
        _userData = {};
        caseId = null;
        _detachCaseListener();
        _notifyListenersAndTrackReady();
        return;
      }

      _userDocExists = true;
      _userData = Map<String, dynamic>.from(snap.data()!);
      final nextCaseId = _userData['caseId'] as String?;
      if (nextCaseId != caseId) {
        caseId = nextCaseId;
        _syncCaseListener(nextCaseId);
      }
      _notifyListenersAndTrackReady();
    });
    await first.future;
  }

  void _syncCaseListener(String? cid) {
    _caseDocSub?.cancel();
    _caseDocSub = null;

    if (cid == null) {
      memberIds = [];
      children = [];
      caseLoading = false;
      _log('[CaseContext] case doc — no caseId, skipping listener');
      return;
    }

    caseLoading = true;
    _log('[CaseContext] case doc — subscribing to cases/$cid');
    _caseDocSub = FirebaseFirestore.instance
        .collection('cases')
        .doc(cid)
        // Same pattern: single subscription for [ChangeNotifier], not parallel [StreamBuilder].
        .snapshots()
        .listen((snap) {
      if (!snap.exists) {
        memberIds = [];
        children = [];
        caseLoading = false;
        _log(
          '[CaseContext] case doc snapshot — missing document '
          '(path=${snap.reference.path})',
        );
        _notifyListenersAndTrackReady();
        return;
      }

      final data = snap.data() as Map<String, dynamic>;
      memberIds = FirestoreFields.readCaseMemberIds(data);
      children = List<dynamic>.from(data['children'] ?? []);
      caseLoading = false;
      _log(
        '[CaseContext] case doc loaded '
        '(path=${snap.reference.path}, members=${memberIds.length})',
      );
      _notifyListenersAndTrackReady();
    });
  }

  void _detachCaseListener() {
    _caseDocSub?.cancel();
    _caseDocSub = null;
    memberIds = [];
    children = [];
    caseLoading = false;
  }

  /// Sync RevenueCat after purchase/restore; updates [isPremium].
  Future<void> refreshPremiumStatus() async {
    if (_user == null) {
      premiumLoading = false;
      _revenueCatPremium = false;
      _notifyListenersAndTrackReady();
      return;
    }

    /// Invite-only counsel accounts are not billed; skip RevenueCat for faster readiness.
    if (isAttorney) {
      premiumLoading = false;
      _revenueCatPremium = false;
      _notifyListenersAndTrackReady();
      return;
    }

    premiumLoading = true;
    _notifyListenersAndTrackReady();

    final previousPremium = _revenueCatPremium;
    try {
      final sub = _subscription;
      if (sub != null) {
        await sub.refresh();
        _syncRcPremiumFromService();
        _log(
          '[CaseContext] refreshPremiumStatus (SubscriptionService) → '
          'revenueCatPremium=$_revenueCatPremium',
        );
      } else {
        _revenueCatPremium = await RevenueCatService.hasProEntitlement();
        _log(
          '[CaseContext] refreshPremiumStatus (direct RC) → '
          'revenueCatPremium=$_revenueCatPremium',
        );
      }
    } catch (e) {
      _revenueCatPremium = previousPremium;
      _log('[CaseContext] refreshPremiumStatus failed (keeping prior): $e');
    }

    premiumLoading = false;
    _notifyListenersAndTrackReady();
  }

  /// Same as [memberIds]; avoid using `parents` in new code.
  List<String> get parents => memberIds;

  String? get coparentId {
    final uid = _user?.uid;
    if (uid == null) return null;
    try {
      return memberIds.firstWhere((id) => id != uid);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearSession() async {
    await _userDocSub?.cancel();
    await _caseDocSub?.cancel();
    _userDocSub = null;
    _caseDocSub = null;

    _user = null;
    _userDocExists = false;
    _userData = {};
    caseId = null;
    _sessionUid = null;
    memberIds = [];
    children = [];

    userDocLoading = true;
    premiumLoading = true;
    _revenueCatPremium = false;

    try {
      await RevenueCatService.logOut();
    } catch (_) {}
    try {
      await _subscription?.handleLoggedOut();
    } catch (_) {}

    _inviteCheckedUid = null;
    _userDocFirstSnapshotDone = false;

    _notifyListenersAndTrackReady();
  }

  /// Called when the user signs out from UI (optional; auth listener also clears).
  Future<void> reset() async {
    await _clearSession();
    authInitializing = false;
    _notifyListenersAndTrackReady();
  }

  @override
  void dispose() {
    _subscription?.removeListener(_onSubscriptionServiceChanged);
    _authSub?.cancel();
    _userDocSub?.cancel();
    _caseDocSub?.cancel();
    super.dispose();
  }
}
