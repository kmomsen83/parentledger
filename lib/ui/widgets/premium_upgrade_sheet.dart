import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../models/premium_feature.dart';
import '../../providers/case_context.dart';
import '../../services/crashlytics_service.dart';
import '../../services/premium_sync_service.dart';
import '../../services/revenuecat_service.dart';
import '../../services/subscription_user_firestore_sync.dart';
import '../paywall_screen.dart';

/// Backward-compatible alias for [PremiumFeature] (existing call sites).
typedef DashboardPremiumFeature = PremiumFeature;

({String title, String valueLine, List<String> bullets}) _copyFor(DashboardPremiumFeature f) {
  switch (f) {
    case DashboardPremiumFeature.insightsCluster:
      return (
        title: 'AI insights & compliance depth',
        valueLine:
            'Surface hidden risk patterns, fairness scoring, and court-ready narratives from your real case data.',
        bullets: [
          'Full fairness scoring on proposals',
          'Deep compliance scan of message threads',
          'Timeline violation drill-down',
        ],
      );
    case DashboardPremiumFeature.caseFile:
      return (
        title: 'Elite Case File',
        valueLine:
            'One secure workspace for exports, finances, activity, and child profiles tied to your matter.',
        bullets: [
          'Court-ready exports & bundles',
          'Live expense ledger tied to your case',
          'Central hub for activity & child profiles',
        ],
      );
    case DashboardPremiumFeature.parentingReport:
      return (
        title: 'Parenting time analytics',
        valueLine:
            'Trend views and summaries that stay credible in negotiation, mediation, or filings.',
        bullets: [
          'Trend views across logged schedule activity',
          'Clear summaries for negotiations & mediation',
        ],
      );
    case DashboardPremiumFeature.complianceReports:
      return (
        title: 'Court-ready reports',
        valueLine:
            'Structured outputs formatted for records — built from your ledger, not generic templates.',
        bullets: [
          'Structured compliance & timeline narratives',
          'PDF outputs formatted for your records',
        ],
      );
    case DashboardPremiumFeature.trustEvidence:
      return (
        title: 'Trust & evidence tools',
        valueLine:
            'Evidence tagging and integrity cues aligned with how family courts evaluate documentation.',
        bullets: [
          'Evidence tagging aligned with your ledger',
          'Integrity indicators for your documentation',
        ],
      );
    case DashboardPremiumFeature.proposals:
      return (
        title: 'Formal proposals',
        valueLine:
            'Structured schedule and financial proposals your co-parent can accept — built for accountability.',
        bullets: [
          'Schedule & expense proposals with clear acceptance states',
          'Thread-linked context so nothing gets lost',
          'Professional record for mediation or court filings',
        ],
      );
    case DashboardPremiumFeature.expenseLedger:
      return (
        title: 'Case expense ledger',
        valueLine:
            'Shared, timestamped expenses tied to your matter — not a generic spreadsheet.',
        bullets: [
          'Track pending and settled amounts per case',
          'Align spending with parenting agreements',
          'Export-ready totals when you upgrade',
        ],
      );
    case DashboardPremiumFeature.documentsLibrary:
      return (
        title: 'Documents library',
        valueLine:
            'Central secure storage for court-facing files linked to your case timeline.',
        bullets: [
          'Organize filings and supporting evidence in one place',
          'Keep versions aligned with messaging and events',
          'Professional presentation when you need it most',
        ],
      );
    case DashboardPremiumFeature.calendarScheduling:
      return (
        title: 'Full calendar & scheduling',
        valueLine:
            'Define repeating custody patterns, add holidays, and schedule exchanges with confidence.',
        bullets: [
          'Set repeating custody schedule & day overrides',
          'Schedule custody exchanges with verified locations',
          'Holiday handling aligned with your parenting plan',
        ],
      );
    case DashboardPremiumFeature.compromiseBoard:
      return (
        title: 'Compromise dashboard',
        valueLine:
            'Structured trade-offs and leverage clarity when negotiating parenting adjustments.',
        bullets: [
          'Scenario comparisons grounded in your logged activity',
          'Clear framing for mediation-ready discussions',
          'Keeps proposals aligned with your case record',
        ],
      );
  }
}

Future<void> showPremiumUpgradeSheet(
  BuildContext context, {
  required DashboardPremiumFeature feature,
}) {
  final cx = context.read<CaseContext>();
  if (cx.isAttorney) {
    return Future<void>.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(
          bottom: bottom + 16,
          left: 16,
          right: 16,
        ),
        child: _PremiumUpgradeSheetBody(
          feature: feature,
          navigatorContext: context,
        ),
      );
    },
  );
}

class _PremiumUpgradeSheetBody extends StatefulWidget {
  const _PremiumUpgradeSheetBody({
    required this.feature,
    required this.navigatorContext,
  });

  final DashboardPremiumFeature feature;
  final BuildContext navigatorContext;

  @override
  State<_PremiumUpgradeSheetBody> createState() => _PremiumUpgradeSheetBodyState();
}

class _PremiumUpgradeSheetBodyState extends State<_PremiumUpgradeSheetBody> {
  late Future<({Package? monthly, Package? yearly})> _packagesFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _packagesFuture = RevenueCatService.loadPackages();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _restore() async {
    if (_busy) return;
    final cx = context.read<CaseContext>();
    final sheetNavigator = Navigator.of(context);
    final snackMessenger = ScaffoldMessenger.of(widget.navigatorContext);
    setState(() => _busy = true);
    try {
      await Purchases.restorePurchases();
      final active = await RevenueCatService.hasProEntitlement();

      if (active) {
        await PremiumSyncService.syncPremiumWithBackend();

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final infoAfter = await Purchases.getCustomerInfo();
          await SubscriptionUserFirestoreSync.applyProEntitlement(
            info: infoAfter,
            planKey: 'restore',
            onboardingStep: null,
          );
          await SubscriptionUserFirestoreSync.syncTrialConsumptionFromCustomerInfo(
            infoAfter,
          );
        }
        if (!mounted) return;
        await cx.refreshPremiumStatus();
        if (!mounted) return;
        sheetNavigator.pop();
        snackMessenger.showSnackBar(
          const SnackBar(content: Text('Membership is active — your records stay organized.')),
        );
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
        reason: 'premium_sheet_restore',
      );
      _snack('Restore failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openPaywall() {
    if (_busy) return;
    if (!mounted) return;
    if (context.read<CaseContext>().isAttorney) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop();
    Navigator.of(widget.navigatorContext).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PaywallScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copyFor(widget.feature);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PLDesign.surface,
            PLDesign.surface.withValues(alpha: 0.97),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: PLDesign.premiumGold.withValues(alpha: 0.38),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: PLDesign.premiumGold.withValues(alpha: 0.1),
            blurRadius: 26,
            spreadRadius: -4,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: PLDesign.premiumGold.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: PLDesign.premiumGold.withValues(alpha: 0.08),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: PLDesign.premiumGold.withValues(alpha: 0.95),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.title,
                        style: PLDesign.sectionTitle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        copy.valueLine,
                        style: PLDesign.body.copyWith(
                          color: PLDesign.textMuted,
                          height: 1.45,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...copy.bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 17,
                        color: PLDesign.premiumGold.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b,
                        style: PLDesign.body.copyWith(height: 1.4, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder(
              future: _packagesFuture,
              builder: (context, snapshot) {
                final m = snapshot.data?.monthly?.storeProduct.priceString;
                final y = snapshot.data?.yearly?.storeProduct.priceString;
                final monthlyLabel = (m != null && m.isNotEmpty) ? m : '—';
                final yearlyLabel = (y != null && y.isNotEmpty) ? y : '—';
                final loading = snapshot.connectionState == ConnectionState.waiting;
                return Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: PLDesign.premiumGold.withValues(alpha: 0.22),
                    ),
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plans',
                        style: PLDesign.caption.copyWith(
                          color: PLDesign.premiumGold.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (loading)
                        Text(
                          'Loading current pricing…',
                          style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Monthly',
                                style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                              ),
                            ),
                            Text(
                              monthlyLabel == '—' ? 'See next screen' : '$monthlyLabel / mo',
                              style: PLDesign.body.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Yearly',
                                style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                              ),
                            ),
                            Text(
                              yearlyLabel == '—' ? 'See next screen' : '$yearlyLabel / yr',
                              style: PLDesign.body.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Exact totals appear at checkout in your currency.',
                        style: PLDesign.caption.copyWith(
                          color: PLDesign.textMuted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Subscriptions renew automatically unless cancelled. '
              'Full access continues during any active trial.',
              style: PLDesign.caption.copyWith(
                color: PLDesign.textMuted,
                height: 1.35,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: PLDesign.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _busy ? null : _openPaywall,
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : _restore,
              child: Text(
                'Restore purchases',
                style: PLDesign.caption.copyWith(
                  color: PLDesign.premiumGold.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(
                'Not now',
                style: PLDesign.caption.copyWith(
                  color: PLDesign.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
