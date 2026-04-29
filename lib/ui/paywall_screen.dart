import 'package:flutter/foundation.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../onboarding/onboarding_steps.dart';
import '../providers/case_context.dart';
import '../services/premium_sync_service.dart';
import '../services/revenuecat_service.dart';
import '../util/store_subscription_links.dart';
import '../services/crashlytics_service.dart';
import 'dashboard_screen.dart';

/// RevenueCat entitlement — must match dashboard configuration.
const String kRevenueCatEntitlementId = RevenueCatService.proEntitlementId;

/// App Store / Play product identifiers (must match store + RevenueCat).
const String kProductMonthlyId = RevenueCatService.monthlyProductId;
const String kProductYearlyId = RevenueCatService.yearlyProductId;

/// Single subscription paywall — shown after onboarding (children / co-parent) via [AppRouter].
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Package? _monthly;
  Package? _yearly;
  String _plan = 'yearly';
  bool _loading = true;
  bool _offeringsFailed = false;
  bool _busy = false;

  late final CustomerInfoUpdateListener _customerInfoListener;

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
      setState(() {
        _monthly = monthly;
        _yearly = yearly;
        _offeringsFailed = monthly == null && yearly == null;
        _loading = false;
      });
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Offerings error');
      }
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

  /// Keeps UI in sync when RevenueCat pushes entitlement updates without hot reload.
  Future<void> _onCustomerInfoUpdated(CustomerInfo info) async {
    final active =
        info.entitlements.active.containsKey(kRevenueCatEntitlementId);
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

  Future<void> _purchase() async {
    if (_busy) return;
    final selected = _plan == 'monthly' ? _monthly : _yearly;
    if (selected == null) {
      _snack(
        'Plans are not available right now. Try again or continue with limited access.',
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final result = await Purchases.purchase(PurchaseParams.package(selected));
      var active = result.customerInfo.entitlements.active
          .containsKey(kRevenueCatEntitlementId);
      if (!active) {
        active = await RevenueCatService.hasProEntitlement();
      }

      if (active) {
        await PremiumSyncService.syncPremiumWithBackend();

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {
              'plan': _plan,
              'onboardingStep': OnboardingSteps.subscribed,
              'subscribedAt': FieldValue.serverTimestamp(),
              'accessLevel': 'subscription',
            },
            SetOptions(merge: true),
          );
        }
        if (!mounted) return;
        await context.read<CaseContext>().refreshPremiumStatus();
        if (!mounted) return;
        _snack('Membership is active — your records stay organized.');
      } else {
        _snack(
          'Checkout finished, but full access isn’t active yet. Try Restore or continue with limited access.',
        );
      }
    } on PlatformException catch (e, st) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        // User dismissed native sheet — optional hint.
      } else {
        await CrashlyticsService.recordError(
          e,
          st,
          reason: 'paywall_purchase_platform',
        );
        _snack(
          'We couldn’t activate membership from the store. Try again or continue without upgrading.',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Purchase error');
      }
      await CrashlyticsService.recordError(
        e,
        st,
        reason: 'paywall_purchase',
      );
      _snack(
        'We couldn’t activate membership from the store. Try again or continue without upgrading.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Purchases.restorePurchases();
      final active = await RevenueCatService.hasProEntitlement();

      if (active) {
        await PremiumSyncService.syncPremiumWithBackend();

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {
              'onboardingStep': OnboardingSteps.subscribed,
              'accessLevel': 'subscription',
            },
            SetOptions(merge: true),
          );
        }
        if (!mounted) return;
        await context.read<CaseContext>().refreshPremiumStatus();
        _snack('Membership is active — your records stay organized.');
      } else {
        _snack('No active membership found for this account.');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Restore error');
      }
      await CrashlyticsService.recordError(
        e,
        st,
        reason: 'paywall_restore',
      );
      _snack('Restore failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueWithLimitedAccess() async {
    if (_busy) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'onboardingStep': OnboardingSteps.onboardingComplete,
          'onboardingLimitedAt': FieldValue.serverTimestamp(),
          'accessLevel': 'free',
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      await context.read<CaseContext>().refreshPremiumStatus();
      if (!mounted) return;
      _snack('Continuing with limited access. You can upgrade anytime from Profile.');
    } catch (_) {
      _snack('Could not continue. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    if (session.hasFullAccess || session.isAttorney) {
      return const DashboardScreen();
    }

    if (_loading) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'lib/design/premium_entry_screen_background.png',
              fit: BoxFit.cover,
            ),
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.72),
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
                        'Loading subscription options…',
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
            ),
          ],
        ),
      );
    }

    if (_offeringsFailed || (_monthly == null && _yearly == null)) {
      return _PaywallScaffold(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  'We couldn’t load plans from the app store. Check your connection and try again — or continue with limited access.',
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
                TextButton(
                  onPressed: _busy ? null : _continueWithLimitedAccess,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
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
    final saveBadge = savePct != null && savePct > 0 ? 'Save $savePct%' : 'Save 33%';
    final monthlyForCopy =
        monthlyStr.isNotEmpty ? monthlyStr : r'$9.99';

    return _PaywallScaffold(
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
                    const SizedBox(height: 4),
                    Text(
                      'ParentLedger',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.15,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Keep a complete, court-ready record of your co-parenting',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: constraints.maxWidth < 360 ? 22 : 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Messages, expenses, and schedules are automatically recorded into a secure timeline you can export anytime.',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        height: 1.45,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _TrustBullet(
                      text:
                          'Secure, unalterable communication records',
                    ),
                    _TrustBullet(
                      text: 'Court-ready timeline of all activity',
                    ),
                    _TrustBullet(
                      text: 'Verified documentation for disputes',
                    ),
                    _TrustBullet(
                      text: 'Everything organized in one place',
                    ),
                    const SizedBox(height: 24),
                    if (_yearly != null)
                      _PremiumPlanCard(
                        title: 'Yearly',
                        priceLine: yearlyStr.isEmpty ? r'$79.99' : yearlyStr,
                        periodSuffix: '/ year',
                        badge: saveBadge,
                        emphasized: true,
                        selected: _plan == 'yearly',
                        onTap: () => setState(() => _plan = 'yearly'),
                      ),
                    if (_yearly != null && _monthly != null)
                      const SizedBox(height: 12),
                    if (_monthly != null)
                      _PremiumPlanCard(
                        title: 'Monthly',
                        priceLine: monthlyStr.isEmpty ? r'$9.99' : monthlyStr,
                        periodSuffix: '/ month',
                        emphasized: false,
                        selected: _plan == 'monthly',
                        onTap: () => setState(() => _plan = 'monthly'),
                      ),
                    const SizedBox(height: 28),
                    Material(
                      color: Colors.transparent,
                      elevation: _busy ? 2 : 10,
                      shadowColor: const Color(0xff6366f1).withValues(alpha: 0.55),
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
                                : const Text(
                                    'Start Free Trial',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Free for 30 days, then $monthlyForCopy/month. Cancel anytime.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All activity is securely recorded and cannot be edited.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PLDesign.info.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Final amount is confirmed in your app store before purchase.',
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
                            child: const Text('Restore Purchases'),
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
                            child: const Text('Manage Subscription'),
                          ),
                        ),
                      ],
                    ),
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
                          foregroundColor: Colors.white.withValues(alpha: 0.45),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: const Text('Skip for now'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Subscriptions are billed through your Apple ID or Google Play account. Cancel anytime in store settings.',
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

/// Single trust row with check — court-forward tone.
class _TrustBullet extends StatelessWidget {
  const _TrustBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.check_circle_rounded,
              size: 22,
              color: const Color(0xff67e8f9).withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.4,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated plan selector — gradient emphasis when [emphasized] and selected.
class _PremiumPlanCard extends StatelessWidget {
  const _PremiumPlanCard({
    required this.title,
    required this.priceLine,
    required this.periodSuffix,
    required this.emphasized,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
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
      child: _PlanCardTap(
        onTap: onTap,
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
                      spreadRadius: 0,
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
                  boxShadow: selected && !emphasized
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
          padding: emphasized && selected
              ? const EdgeInsets.all(2)
              : EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(emphasized && selected ? 18 : 20),
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
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: selected ? 1 : 0.82,
                              ),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (badge != null && emphasized) ...[
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
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          children: [
                            TextSpan(text: priceLine),
                            TextSpan(
                              text: ' $periodSuffix',
                              style: TextStyle(
                                fontSize: 15,
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
                          size: 28,
                        )
                      : Icon(
                          Icons.circle_outlined,
                          key: const ValueKey('off'),
                          color: Colors.white.withValues(alpha: 0.28),
                          size: 28,
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

/// Tap wrapper for plan rows (parent [Material] provides CTA ripple).
class _PlanCardTap extends StatelessWidget {
  const _PlanCardTap({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

class _PaywallScaffold extends StatelessWidget {
  const _PaywallScaffold({required this.child});

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
            child: Container(color: Colors.black.withValues(alpha: 0.72)),
          ),
          child,
        ],
      ),
    );
  }
}
