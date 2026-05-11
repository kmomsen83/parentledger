import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../onboarding/onboarding_steps.dart';
import '../../providers/case_context.dart';
import '../../services/crashlytics_service.dart';
import '../../services/premium_sync_service.dart';
import '../../services/revenuecat_service.dart';
import '../../services/subscription_user_firestore_sync.dart';
import '../../util/store_subscription_links.dart';
import '../dashboard_screen.dart';

/// Onboarding paywall vs profile manage plan — same premium UI, different chrome.
enum SubscriptionPlansSurface {
  onboarding,
  manage,
}

/// RevenueCat-backed parent subscription UI (trial + monthly + yearly).
class ParentLedgerSubscriptionPlansScaffold extends StatefulWidget {
  const ParentLedgerSubscriptionPlansScaffold({
    super.key,
    required this.surface,
  });

  final SubscriptionPlansSurface surface;

  @override
  State<ParentLedgerSubscriptionPlansScaffold> createState() =>
      _ParentLedgerSubscriptionPlansScaffoldState();
}

class _ParentLedgerSubscriptionPlansScaffoldState
    extends State<ParentLedgerSubscriptionPlansScaffold> {
  static const String _kEntitlement = RevenueCatService.proEntitlementId;

  Package? _monthly;
  Package? _yearly;

  /// `trial` uses [PackageType.monthly] when store offers intro; otherwise hidden.
  String _plan = 'yearly';
  bool _loading = true;
  bool _offeringsFailed = false;
  bool _busy = false;

  late final CustomerInfoUpdateListener _customerInfoListener;

  bool get _isManage => widget.surface == SubscriptionPlansSurface.manage;

  bool _trialVisible(CaseContext cx) {
    if (_monthly == null) return false;
    if (cx.freeTrialUsed) return false;
    if (_isManage && cx.hasFullAccess) return false;
    return true;
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _loading = true;
      _offeringsFailed = false;
      _monthly = null;
      _yearly = null;
    });

    try {
      final packages = await RevenueCatService.loadPackages();
      final monthly = packages.monthly;
      final yearly = packages.yearly;
      if (monthly == null && yearly == null) {
        if (!mounted) return;
        setState(() {
          _offeringsFailed = true;
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      final cx = context.read<CaseContext>();
      var plan = _plan;
      if (!_trialVisible(cx) && plan == 'trial') {
        plan = yearly != null ? 'yearly' : 'monthly';
      }
      setState(() {
        _monthly = monthly;
        _yearly = yearly;
        _offeringsFailed = monthly == null && yearly == null;
        _loading = false;
        _plan = plan;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _offeringsFailed = true;
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _customerInfoListener = _onCustomerInfoUpdated;
    Purchases.addCustomerInfoUpdateListener(_customerInfoListener);
    _loadOfferings();
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_customerInfoListener);
    super.dispose();
  }

  Future<void> _onCustomerInfoUpdated(CustomerInfo info) async {
    final active = info.entitlements.active.containsKey(_kEntitlement);
    if (!active || !mounted) return;

    await PremiumSyncService.syncPremiumWithBackend();
    if (!mounted) return;
    try {
      await context.read<CaseContext>().refreshPremiumStatus();
    } catch (_) {}
  }

  int? _savingsPercent() {
    final m = _monthly?.storeProduct;
    final y = _yearly?.storeProduct;
    if (m == null || y == null) return null;
    final monthlyAnnualized = m.price * 12;
    if (monthlyAnnualized <= 0) return null;
    final raw = (1 - (y.price / monthlyAnnualized)) * 100;
    return raw.clamp(0, 99).round();
  }

  Package? _selectedPackage() {
    switch (_plan) {
      case 'trial':
      case 'monthly':
        return _monthly;
      case 'yearly':
      default:
        return _yearly;
    }
  }

  Future<void> _purchase() async {
    if (_busy) return;
    final selected = _selectedPackage();
    if (selected == null) {
      _snack(
        'Plans are not available right now. Try again or continue with limited access.',
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final info = await Purchases.purchasePackage(selected);
      var active = info.entitlements.active.containsKey(_kEntitlement);
      if (!active) {
        active = await RevenueCatService.hasProEntitlement();
      }

      if (active) {
        await PremiumSyncService.syncPremiumWithBackend();
        final planKey = _plan == 'trial' ? 'monthly_trial' : _plan;
        await SubscriptionUserFirestoreSync.applyProEntitlement(
          info: info,
          planKey: planKey,
          onboardingStep: _isManage ? null : OnboardingSteps.subscribed,
        );
        await SubscriptionUserFirestoreSync
            .syncTrialConsumptionFromCustomerInfo(
          info,
        );
        if (!mounted) return;
        await context.read<CaseContext>().refreshPremiumStatus();
        if (!mounted) return;
        _snack(
            'You’re all set — calm, organized co-parenting stays within reach.');
        if (_isManage && mounted) {
          Navigator.of(context).maybePop();
        }
      } else {
        _snack(
          'Checkout finished, but full access isn’t active yet. Try Restore or contact support.',
        );
      }
    } on PlatformException catch (e, st) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        await CrashlyticsService.recordError(
          e,
          st,
          reason: 'subscription_purchase_platform',
        );
        _snack(
          'We couldn’t complete that from the store. Try again when you’re ready.',
        );
      }
    } catch (e, st) {
      await CrashlyticsService.recordError(
        e,
        st,
        reason: 'subscription_purchase',
      );
      _snack(
        'We couldn’t complete that from the store. Try again when you’re ready.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final info = await Purchases.restorePurchases();
      final active = info.entitlements.active.containsKey(_kEntitlement);

      if (active) {
        await PremiumSyncService.syncPremiumWithBackend();
        await SubscriptionUserFirestoreSync.applyProEntitlement(
          info: info,
          planKey: 'restore',
          onboardingStep: _isManage ? null : OnboardingSteps.subscribed,
        );
        await SubscriptionUserFirestoreSync
            .syncTrialConsumptionFromCustomerInfo(
          info,
        );
        if (!mounted) return;
        await context.read<CaseContext>().refreshPremiumStatus();
        _snack('Membership is active — your records stay organized.');
        if (_isManage && mounted) {
          Navigator.of(context).maybePop();
        }
      } else {
        _snack('No active membership found for this account.');
      }
    } catch (e, st) {
      await CrashlyticsService.recordError(
        e,
        st,
        reason: 'subscription_restore',
      );
      _snack('Restore failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueWithLimitedAccess() async {
    if (_busy || _isManage) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      await SubscriptionUserFirestoreSync.markFreeTierContinue();
      if (!mounted) return;
      await context.read<CaseContext>().refreshPremiumStatus();
      if (!mounted) return;
      _snack(
          'Continuing with limited access. You can upgrade anytime from Profile.');
    } catch (_) {
      _snack('Could not continue. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _ctaLabel() {
    if (_plan == 'trial') return 'Start one-month free trial';
    return 'Subscribe with calm confidence';
  }

  String _ctaFootnote(String monthlyForCopy) {
    if (_plan == 'trial') {
      return 'Free trial length is confirmed in the store before you subscribe. '
          'After the trial, billing continues as a monthly membership unless you cancel.';
    }
    if (_plan == 'yearly') {
      return 'Billed annually. Cancel anytime in your store account settings.';
    }
    return 'Billed monthly ($monthlyForCopy). Cancel anytime in your store account settings.';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();

    if (!_isManage && (session.hasFullAccess || session.isAttorney)) {
      return const DashboardScreen();
    }

    if (_loading) {
      return _PremiumBackdrop(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ParentLedger',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Color(0xff818cf8),
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Preparing your membership options…',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_offeringsFailed || (_monthly == null && _yearly == null)) {
      return _PremiumBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isManage)
                  _ManageBackRow(onBack: () => Navigator.pop(context)),
                const Spacer(),
                Text(
                  'Plans unavailable',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'We couldn’t load plans from the store. Check your connection and try again — or continue with limited access.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _busy ? null : _loadOfferings,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xff4f7cff),
                  ),
                  child: Text(context.tTone('retry')),
                ),
                if (!_isManage) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _continueWithLimitedAccess,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    child: Text(context.tTone('continueWithLimitedAccess')),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

    final monthlyStr = _monthly?.storeProduct.priceString ?? '';
    final yearlyStr = _yearly?.storeProduct.priceString ?? '';
    final savePct = _savingsPercent();
    final saveBadge =
        savePct != null && savePct > 0 ? 'Save $savePct%' : 'Best value';
    final monthlyForCopy = monthlyStr.isNotEmpty ? monthlyStr : r'$9.99';

    final showTrial = _trialVisible(session);

    return _PremiumBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isManage)
                      _ManageBackRow(onBack: () => Navigator.pop(context)),
                    const SizedBox(height: 4),
                    Text(
                      _isManage ? 'Manage plan' : 'ParentLedger',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isManage
                          ? 'Choose the pace that fits your family'
                          : 'A gentle space for what matters most',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: constraints.maxWidth < 360 ? 22 : 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isManage
                          ? 'Upgrade, switch billing, or restore a previous membership. '
                              'Everything stays private and organized.'
                          : 'Court-ready records, shared scheduling, and secure messaging — '
                              'without the noise.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        height: 1.45,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _PremiumBenefitsList(),
                    const SizedBox(height: 22),
                    if (showTrial && _monthly != null)
                      _PremiumPlanCard(
                        title: 'One month free trial',
                        subtitle: 'Then continues as monthly membership',
                        priceLine: monthlyStr.isEmpty ? r'$9.99' : monthlyStr,
                        periodSuffix: '/ month after trial',
                        emphasized: true,
                        selected: _plan == 'trial',
                        onTap: () => setState(() => _plan = 'trial'),
                      ),
                    if (showTrial && _monthly != null)
                      const SizedBox(height: 12),
                    if (_monthly != null)
                      _PremiumPlanCard(
                        title: 'Monthly',
                        subtitle: 'Flexible month-to-month',
                        priceLine: monthlyStr.isEmpty ? r'$9.99' : monthlyStr,
                        periodSuffix: '/ month',
                        emphasized: false,
                        selected: _plan == 'monthly',
                        onTap: () => setState(() => _plan = 'monthly'),
                      ),
                    if (_monthly != null && _yearly != null)
                      const SizedBox(height: 12),
                    if (_yearly != null)
                      _PremiumPlanCard(
                        title: 'Yearly',
                        subtitle: 'Most families choose this for peace of mind',
                        priceLine: yearlyStr.isEmpty ? r'$79.99' : yearlyStr,
                        periodSuffix: '/ year',
                        badge: saveBadge,
                        emphasized: true,
                        selected: _plan == 'yearly',
                        onTap: () => setState(() => _plan = 'yearly'),
                      ),
                    const SizedBox(height: 28),
                    Material(
                      color: Colors.transparent,
                      elevation: _busy ? 2 : 10,
                      shadowColor:
                          const Color(0xff6366f1).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _busy ? null : _purchase,
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xff6366f1),
                                Color(0xff3b82f6),
                                Color(0xff2563eb),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xff4f46e5)
                                    .withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _busy
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _ctaLabel(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _ctaFootnote(monthlyForCopy),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Pricing is confirmed by Apple or Google before you pay.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _busy ? null : _restore,
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Colors.white.withValues(alpha: 0.65),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Restore purchases'),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    final ok =
                                        await launchManageSubscriptionsInStore();
                                    if (!mounted) return;
                                    if (!ok) {
                                      _snack(
                                        'Could not open subscription settings.',
                                      );
                                    }
                                  },
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Colors.white.withValues(alpha: 0.65),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Manage in store'),
                          ),
                        ),
                      ],
                    ),
                    if (!_isManage) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy ? null : _continueWithLimitedAccess,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: Colors.white.withValues(alpha: 0.9),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(context.tTone('continueWithLimitedAccess')),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: _busy ? null : _continueWithLimitedAccess,
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Colors.white.withValues(alpha: 0.45),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          child: const Text('Skip for now'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Subscriptions bill through your Apple ID or Google Play account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ManageBackRow extends StatelessWidget {
  const _ManageBackRow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      ),
    );
  }
}

class _PremiumBackdrop extends StatelessWidget {
  const _PremiumBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/design/premium_entry_screen_background.png',
            fit: BoxFit.cover,
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.72)),
          ),
          child,
        ],
      ),
    );
  }
}

class _PremiumBenefitsList extends StatelessWidget {
  const _PremiumBenefitsList();

  static const _items = [
    'Shared calendar built for custody rhythms',
    'Expense tracking with clear categories',
    'Secure messaging with a calm tone',
    'Court-ready reports when you need them',
    'Timeline tracking across every exchange',
    'AI insights that respect your privacy',
    'Secure document storage',
    'Unlimited exports for your records',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _items
          .map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: const Color(0xff67e8f9).withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.38,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PremiumPlanCard extends StatelessWidget {
  const _PremiumPlanCard({
    required this.title,
    required this.subtitle,
    required this.priceLine,
    required this.periodSuffix,
    required this.emphasized,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String priceLine;
  final String periodSuffix;
  final bool emphasized;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  static const _accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xff818cf8),
      Color(0xff6366f1),
      Color(0xff3b82f6),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: emphasized && selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: _accentGradient,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff6366f1).withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                )
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: selected
                        ? const Color(0xff6366f1).withValues(alpha: 0.65)
                        : Colors.white.withValues(alpha: 0.14),
                    width: selected ? 1.6 : 1,
                  ),
                ),
          padding: emphasized && selected
              ? const EdgeInsets.all(2)
              : EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(emphasized && selected ? 18 : 20),
              color: emphasized && selected
                  ? const Color(0xff0f172a).withValues(alpha: 0.97)
                  : Colors.transparent,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: Colors.white.withValues(
                                  alpha: selected ? 1 : 0.82,
                                ),
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (badge != null && emphasized && selected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xfffbbf24)
                                        .withValues(alpha: 0.35),
                                    const Color(0xfff59e0b)
                                        .withValues(alpha: 0.28),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xfffbbf24)
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xfffef3c7),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          children: [
                            TextSpan(text: priceLine),
                            TextSpan(
                              text: ' $periodSuffix',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selected
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: const ValueKey('on'),
                          color: emphasized
                              ? const Color(0xff818cf8)
                              : PLDesign.primary,
                          size: 26,
                        )
                      : Icon(
                          Icons.circle_outlined,
                          key: const ValueKey('off'),
                          color: Colors.white.withValues(alpha: 0.28),
                          size: 26,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
