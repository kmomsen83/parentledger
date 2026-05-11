import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/design.dart';
import '../../providers/case_context.dart';
import '../../services/revenuecat_service.dart';
import '../../util/store_subscription_links.dart';

class RefundHelpScreen extends StatefulWidget {
  const RefundHelpScreen({super.key});

  @override
  State<RefundHelpScreen> createState() => _RefundHelpScreenState();
}

class _RefundHelpScreenState extends State<RefundHelpScreen> {
  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();
  bool _loadingSupport = false;
  bool _loadingPlay = false;
  Future<CustomerInfo?>? _customerInfoFuture;

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static const String _supportEmail = 'support@parentledgerinfo.com';

  _RefundText _t(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    final apple = Platform.isIOS;
    return lang == 'es'
        ? _RefundText.es(apple: apple)
        : _RefundText.en(apple: apple);
  }

  @override
  void initState() {
    super.initState();
    _analytics.logEvent(name: 'refund_help_opened');
    _noteFocus.addListener(() => setState(() {}));
    _refreshCustomerInfo();
  }

  void _refreshCustomerInfo() {
    setState(() {
      _customerInfoFuture = _loadCustomerInfoSafe();
    });
  }

  Future<CustomerInfo?> _loadCustomerInfoSafe() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _noteFocus.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _hapticLight() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  Future<void> openStoreSubscriptions() async {
    final t = _t(context);
    final confirmed = await _confirmOpenStore(t);
    if (confirmed != true) return;
    if (_loadingPlay) return;
    await _hapticLight();
    if (!mounted) return;
    setState(() => _loadingPlay = true);
    final uri = manageSubscriptionsUri();
    try {
      await _analytics.logEvent(name: 'refund_store_subscriptions_opened');
      var opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.storeOpenFallback)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.storeOpenFallback)),
      );
    } finally {
      if (mounted) setState(() => _loadingPlay = false);
    }
  }

  Future<void> _contactSupport() async {
    if (_loadingSupport) return;
    await _hapticLight();
    if (!mounted) return;
    setState(() => _loadingSupport = true);
    await _analytics.logEvent(name: 'refund_contact_support_clicked');

    final user = FirebaseAuth.instance.currentUser;
    final note = _noteController.text.trim();
    final appInfo = await PackageInfo.fromPlatform();
    final platform = Platform.operatingSystem;
    final userEmail = user?.email ?? '';
    final userId = user?.uid ?? '';
    final fallbackBody =
        'User ID: $userId\nEmail: $userEmail\nApp Version: ${appInfo.version}+${appInfo.buildNumber}\nPlatform: $platform\nIssue: refund_request\nNote: ${note.isEmpty ? 'N/A' : note}';

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendSupportEmail');
      await callable.call(<String, dynamic>{
        'userId': userId,
        'email': userEmail,
        'issue': 'refund_request',
        'message': note,
        'appVersion': '${appInfo.version}+${appInfo.buildNumber}',
        'platform': platform,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(context).supportRequestSent)),
      );
    } catch (_) {
      final mailto = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        queryParameters: {
          'subject': 'Subscription support',
          'body': fallbackBody,
        },
      );
      final launched = await launchUrl(mailto);
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t(context).supportRequestFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSupport = false);
    }
  }

  String _planDisplayName(CaseContext cx, CustomerInfo? info) {
    if (cx.isAttorney) {
      return _t(context).planAttorney;
    }
    final tier = cx.subscriptionTier;
    if (!cx.hasRevenueCatPremium && !cx.isPremium) {
      return _t(context).planFree;
    }
    final id = RevenueCatService.proEntitlementId;
    final ent = info?.entitlements.active[id];
    final product = ent?.productIdentifier ?? '';
    if (product.contains('year') || product.contains('annual')) {
      return _t(context).planPremiumAnnual;
    }
    if (product.contains('month')) {
      return _t(context).planPremiumMonthly;
    }
    if (tier.contains('parent_pro') || cx.isPremium) {
      return _t(context).planPremium;
    }
    return _t(context).planPremium;
  }

  String? _renewalLine(_RefundText t, CustomerInfo? info, CaseContext cx) {
    if (cx.isAttorney) return null;
    final id = RevenueCatService.proEntitlementId;
    final ent = info?.entitlements.active[id];
    if (ent == null) return null;
    final expStr = ent.expirationDate;
    if (expStr == null || expStr.isEmpty) return null;
    final exp = DateTime.tryParse(expStr);
    if (exp == null) return null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat.yMMMMd(locale);
    if (ent.periodType == PeriodType.trial) {
      return t.renewsTrial(fmt.format(exp));
    }
    if (ent.willRenew == false) {
      return t.accessEnds(fmt.format(exp));
    }
    return t.renewsOn(fmt.format(exp));
  }

  String _statusLine(_RefundText t, CustomerInfo? info, CaseContext cx) {
    if (cx.isAttorney) return t.statusAttorney;
    final id = RevenueCatService.proEntitlementId;
    final ent = info?.entitlements.active[id];
    if (ent != null) {
      if (ent.periodType == PeriodType.trial) return t.statusTrialing;
      return t.statusActive;
    }
    final st = cx.subscriptionStatus.toLowerCase();
    if (st == 'trialing') return t.statusTrialing;
    if (st == 'active') return t.statusActive;
    if (st == 'free') return t.statusFree;
    return t.statusNoSubscription;
  }

  String? _trialLine(_RefundText t, CustomerInfo? info, CaseContext cx) {
    if (cx.isAttorney) return null;
    final id = RevenueCatService.proEntitlementId;
    final ent = info?.entitlements.active[id];
    if (ent?.periodType == PeriodType.trial) {
      return t.trialInProgress;
    }
    if (cx.freeTrialUsed && ent == null) {
      return t.trialUsed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final textScaler = MediaQuery.textScalerOf(context);
    final cx = context.watch<CaseContext>();

    return Semantics(
      label: t.semanticsScreenLabel,
      child: Scaffold(
        backgroundColor: PLDesign.background,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(
            t.appBarTitle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          backgroundColor: PLDesign.surface,
          foregroundColor: PLDesign.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: DecoratedBox(
          decoration: PLDesign.screenGradient,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxContent = constraints.maxWidth.clamp(0.0, 520.0);
                final hPad = (constraints.maxWidth * 0.045).clamp(16.0, 24.0);

                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContent),
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.fromLTRB(
                        hPad,
                        12,
                        hPad,
                        24 + bottomInset,
                      ),
                      child: CustomScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _IntroCard(t: t, textScaler: textScaler)
                                    .animate()
                                    .fadeIn(
                                        duration: 280.ms, curve: Curves.easeOut)
                                    .slideY(
                                      begin: 0.04,
                                      end: 0,
                                      duration: 320.ms,
                                      curve: Curves.easeOutCubic,
                                    ),
                                const SizedBox(height: 16),
                                _SubscriptionStatusCard(
                                  future: _customerInfoFuture,
                                  cx: cx,
                                  t: t,
                                  textScaler: textScaler,
                                  planName: (info) =>
                                      _planDisplayName(cx, info),
                                  renewalLine: (info) =>
                                      _renewalLine(t, info, cx),
                                  statusLine: (info) =>
                                      _statusLine(t, info, cx),
                                  trialLine: (info) => _trialLine(t, info, cx),
                                  onRetry: _refreshCustomerInfo,
                                ).animate().fadeIn(
                                      delay: 40.ms,
                                      duration: 300.ms,
                                    ),
                                const SizedBox(height: 14),
                                _PolicyCard(t: t, textScaler: textScaler),
                                const SizedBox(height: 20),
                                _PrimaryStoreButton(
                                  loading: _loadingPlay,
                                  label: t.openSubscriptionSettings,
                                  onTap: openStoreSubscriptions,
                                )
                                    .animate()
                                    .fadeIn(delay: 80.ms, duration: 280.ms),
                                const SizedBox(height: 16),
                                Text(
                                  t.helpAfterStore,
                                  style: PLDesign.body.copyWith(
                                    fontSize: 13 *
                                        textScaler.scale(1).clamp(0.9, 1.25),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _NoteField(
                                  controller: _noteController,
                                  focusNode: _noteFocus,
                                  label: t.noteLabel,
                                  hint: t.noteHint,
                                  textScaler: textScaler,
                                ),
                                const SizedBox(height: 16),
                                _GlassSupportButton(
                                  loading: _loadingSupport,
                                  label: t.contactSupport,
                                  onTap: _contactSupport,
                                )
                                    .animate()
                                    .fadeIn(delay: 120.ms, duration: 280.ms),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmOpenStore(_RefundText t) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: Text(
          t.confirmTitle,
          style: PLDesign.sectionTitle,
        ),
        content: SingleChildScrollView(
          child: Text(
            t.confirmBody,
            style: PLDesign.body.copyWith(height: 1.4),
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.continueText),
          ),
        ],
      ),
    );
  }
}

// --- UI blocks -----------------------------------------------------------------

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.t,
    required this.textScaler,
  });

  final _RefundText t;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: PLDesign.gradientCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: 26,
                color: PLDesign.premiumGold.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.subtitle,
                  style: PLDesign.body.copyWith(
                    fontSize: 14 * textScaler.scale(1).clamp(0.92, 1.2),
                    height: 1.4,
                    color: PLDesign.textPrimary.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t.explainer,
            style: PLDesign.caption.copyWith(
              fontSize: 12.5 * textScaler.scale(1).clamp(0.9, 1.15),
              height: 1.42,
              color: PLDesign.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.t,
    required this.textScaler,
  });

  final _RefundText t;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PLDesign.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PLDesign.border.withValues(alpha: 0.85)),
      ),
      child: Text(
        t.policyCard,
        style: PLDesign.caption.copyWith(
          fontSize: 12.5 * textScaler.scale(1).clamp(0.9, 1.12),
          height: 1.4,
          color: PLDesign.textMuted,
        ),
      ),
    );
  }
}

class _SubscriptionStatusCard extends StatelessWidget {
  const _SubscriptionStatusCard({
    required this.future,
    required this.cx,
    required this.t,
    required this.textScaler,
    required this.planName,
    required this.renewalLine,
    required this.statusLine,
    required this.trialLine,
    required this.onRetry,
  });

  final Future<CustomerInfo?>? future;
  final CaseContext cx;
  final _RefundText t;
  final TextScaler textScaler;
  final String Function(CustomerInfo?) planName;
  final String? Function(CustomerInfo?) renewalLine;
  final String Function(CustomerInfo?) statusLine;
  final String? Function(CustomerInfo?) trialLine;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: PLDesign.premiumCaseCardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PLDesign.premiumChampagne.withValues(alpha: 0.22),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: FutureBuilder<CustomerInfo?>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.statusCardTitle,
                  style: PLDesign.caption.copyWith(
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                    color: PLDesign.premiumChampagne.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 14),
                _ShimmerBar(width: double.infinity, height: 16),
                const SizedBox(height: 10),
                _ShimmerBar(width: 180, height: 12),
                const SizedBox(height: 8),
                _ShimmerBar(width: 220, height: 12),
              ],
            );
          }

          if (snap.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.statusCardTitle, style: _cardEyebrow()),
                const SizedBox(height: 8),
                Text(
                  t.statusLoadError,
                  style: _cardBody(),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: Text(t.retry),
                ),
              ],
            );
          }

          final info = snap.data;
          final plan = planName(info);
          final renewal = renewalLine(info);
          final status = statusLine(info);
          final trial = trialLine(info);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.statusCardTitle, style: _cardEyebrow()),
              const SizedBox(height: 10),
              Text(
                plan,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 20 * textScaler.scale(1).clamp(0.88, 1.2),
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: PLDesign.textPrimary,
                ),
              ),
              if (renewal != null && renewal.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  renewal,
                  style: _cardBody(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusChip(label: status),
                  if (trial != null && trial.isNotEmpty)
                    _StatusChip(
                      label: trial,
                      emphasized: true,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  TextStyle _cardEyebrow() => PLDesign.caption.copyWith(
        letterSpacing: 0.85,
        fontWeight: FontWeight.w800,
        color: PLDesign.premiumChampagne.withValues(alpha: 0.78),
      );

  TextStyle _cardBody() => PLDesign.body.copyWith(
        fontSize: 13.5 * textScaler.scale(1).clamp(0.9, 1.15),
        height: 1.35,
        color: PLDesign.textMuted,
      );
}

class _ShimmerBar extends StatefulWidget {
  const _ShimmerBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ShaderMask(
            shaderCallback: (bounds) {
              final t = _c.value;
              return LinearGradient(
                begin: Alignment(-1.2 + t * 2.4, 0),
                end: Alignment(-0.2 + t * 2.4, 0),
                colors: [
                  const Color(0xff1e293b),
                  const Color(0xff334155),
                  const Color(0xff1e293b),
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xff1e293b),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    this.emphasized = false,
  });

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final bg = emphasized
        ? PLDesign.info.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.08);
    final border = emphasized
        ? PLDesign.info.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: PLDesign.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: emphasized
              ? PLDesign.info.withValues(alpha: 0.95)
              : PLDesign.textMuted,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PrimaryStoreButton extends StatelessWidget {
  const _PrimaryStoreButton({
    required this.loading,
    required this.label,
    required this.onTap,
  });

  final bool loading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        elevation: loading ? 2 : 8,
        shadowColor: const Color(0xff4f46e5).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: loading ? null : onTap,
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff6366f1),
                  Color(0xff4f7cff),
                  Color(0xff2563eb),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff4f46e5).withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PLDesign.buttonText.copyWith(
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.textScaler,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    return Semantics(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: PLDesign.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: PLDesign.textMuted,
              fontSize: 11.5 * textScaler.scale(1).clamp(0.9, 1.12),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                width: focused ? 1.35 : 1,
                color: focused
                    ? PLDesign.primary.withValues(alpha: 0.75)
                    : PLDesign.border.withValues(alpha: 0.9),
              ),
              color: PLDesign.surface.withValues(alpha: 0.94),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLength: 300,
              minLines: 2,
              maxLines: 4,
              style: PLDesign.body.copyWith(
                fontSize: 14 * textScaler.scale(1).clamp(0.92, 1.18),
                height: 1.35,
                color: PLDesign.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: PLDesign.caption.copyWith(
                  color: PLDesign.textMuted.withValues(alpha: 0.55),
                  fontSize: 13,
                  height: 1.3,
                ),
                counterText: '',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              ),
              buildCounter: (BuildContext _,
                  {required int currentLength,
                  required bool isFocused,
                  required int? maxLength}) {
                return const SizedBox.shrink();
              },
            ),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${value.text.length}/300',
                  style: PLDesign.caption.copyWith(
                    fontSize: 11,
                    color: PLDesign.textMuted.withValues(alpha: 0.75),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GlassSupportButton extends StatelessWidget {
  const _GlassSupportButton({
    required this.loading,
    required this.label,
    required this.onTap,
  });

  final bool loading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: loading ? null : onTap,
          splashColor: PLDesign.primary.withValues(alpha: 0.12),
          highlightColor: PLDesign.primary.withValues(alpha: 0.06),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.03),
                ],
              ),
              border: Border.all(
                color: PLDesign.primary.withValues(alpha: 0.35),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: PLDesign.primary.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: loading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.support_agent_rounded,
                            color: PLDesign.info.withValues(alpha: 0.95),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: PLDesign.secondaryButtonText.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.15,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Copy ----------------------------------------------------------------------

class _RefundText {
  _RefundText({
    required this.appBarTitle,
    required this.semanticsScreenLabel,
    required this.subtitle,
    required this.explainer,
    required this.policyCard,
    required this.openSubscriptionSettings,
    required this.helpAfterStore,
    required this.noteLabel,
    required this.noteHint,
    required this.contactSupport,
    required this.storeOpenFallback,
    required this.supportRequestSent,
    required this.supportRequestFailed,
    required this.confirmTitle,
    required this.confirmBody,
    required this.cancel,
    required this.continueText,
    required this.statusCardTitle,
    required this.statusLoadError,
    required this.retry,
    required this.planFree,
    required this.planPremium,
    required this.planPremiumMonthly,
    required this.planPremiumAnnual,
    required this.planAttorney,
    required this.renewsOn,
    required this.renewsTrial,
    required this.accessEnds,
    required this.statusTrialing,
    required this.statusActive,
    required this.statusFree,
    required this.statusNoSubscription,
    required this.statusAttorney,
    required this.trialInProgress,
    required this.trialUsed,
  });

  final String appBarTitle;
  final String semanticsScreenLabel;
  final String subtitle;
  final String explainer;
  final String policyCard;
  final String openSubscriptionSettings;
  final String helpAfterStore;
  final String noteLabel;
  final String noteHint;
  final String contactSupport;
  final String storeOpenFallback;
  final String supportRequestSent;
  final String supportRequestFailed;
  final String confirmTitle;
  final String confirmBody;
  final String cancel;
  final String continueText;
  final String statusCardTitle;
  final String statusLoadError;
  final String retry;
  final String planFree;
  final String planPremium;
  final String planPremiumMonthly;
  final String planPremiumAnnual;
  final String planAttorney;
  final String Function(String date) renewsOn;
  final String Function(String date) renewsTrial;
  final String Function(String date) accessEnds;
  final String statusTrialing;
  final String statusActive;
  final String statusFree;
  final String statusNoSubscription;
  final String statusAttorney;
  final String trialInProgress;
  final String trialUsed;

  factory _RefundText.en({required bool apple}) => _RefundText(
        appBarTitle: 'Subscription support',
        semanticsScreenLabel: 'Billing and subscription help',
        subtitle: apple
            ? 'Subscriptions are managed securely through the App Store.'
            : 'Subscriptions are managed securely through Google Play.',
        explainer: apple
            ? 'You can review renewal, change plans, or request a refund from Apple’s subscription settings.'
            : 'You can review renewal, change plans, or request a refund from Google Play’s subscription center.',
        policyCard: apple
            ? 'Refund eligibility follows Apple’s policies. ParentLedger cannot override App Store billing decisions.'
            : 'Refund eligibility follows Google Play policies. ParentLedger cannot override Play billing decisions.',
        openSubscriptionSettings: apple
            ? 'Open App Store subscriptions'
            : 'Open Play Store subscriptions',
        helpAfterStore:
            'Need additional help? Our support team is here to assist you.',
        noteLabel: 'Message for support (optional)',
        noteHint: 'Brief context helps us resolve billing questions faster…',
        contactSupport: 'Contact support',
        storeOpenFallback: apple
            ? "Couldn't open Settings. Try again from the App Store account menu."
            : "Couldn't open Play Store. Opening in your browser instead.",
        supportRequestSent:
            'We received your message. Our team will follow up shortly.',
        supportRequestFailed:
            'Something went wrong. Please email support@parentledgerinfo.com',
        confirmTitle: apple ? 'Open App Store?' : 'Open Google Play?',
        confirmBody: apple
            ? 'You’ll leave ParentLedger to open Apple’s subscription management. You can request a refund there if eligible.'
            : 'You’ll leave ParentLedger to open Google Play’s subscription center. You can request a refund there if eligible.',
        cancel: 'Cancel',
        continueText: 'Continue',
        statusCardTitle: 'ACCOUNT STATUS',
        statusLoadError: 'Could not load subscription details.',
        retry: 'Retry',
        planFree: 'ParentLedger — free tier',
        planPremium: 'ParentLedger Premium',
        planPremiumMonthly: 'ParentLedger Premium — monthly',
        planPremiumAnnual: 'ParentLedger Premium — annual',
        planAttorney: 'Professional access (counsel)',
        renewsOn: (d) => 'Renews $d',
        renewsTrial: (d) => 'Trial converts · access through $d',
        accessEnds: (d) => 'Access ends $d',
        statusTrialing: 'Free trial',
        statusActive: 'Active',
        statusFree: 'Free',
        statusNoSubscription: 'No active subscription',
        statusAttorney: 'Included with your workspace',
        trialInProgress: 'Trial active',
        trialUsed: 'Intro offer used',
      );

  factory _RefundText.es({required bool apple}) => _RefundText(
        appBarTitle: 'Soporte de suscripción',
        semanticsScreenLabel: 'Ayuda de facturación y suscripción',
        subtitle: apple
            ? 'Las suscripciones se gestionan de forma segura en el App Store.'
            : 'Las suscripciones se gestionan de forma segura en Google Play.',
        explainer: apple
            ? 'Puedes revisar la renovación, cambiar de plan o solicitar un reembolso desde los ajustes de suscripciones de Apple.'
            : 'Puedes revisar la renovación, cambiar de plan o solicitar un reembolso desde el centro de suscripciones de Google Play.',
        policyCard: apple
            ? 'La elegibilidad de reembolso sigue las políticas de Apple. ParentLedger no puede anular decisiones de facturación del App Store.'
            : 'La elegibilidad de reembolso sigue las políticas de Google Play. ParentLedger no puede anular decisiones de facturación de Play.',
        openSubscriptionSettings: apple
            ? 'Abrir suscripciones del App Store'
            : 'Abrir suscripciones de Google Play',
        helpAfterStore:
            '¿Necesitas más ayuda? Nuestro equipo de soporte está aquí para asistirte.',
        noteLabel: 'Mensaje para soporte (opcional)',
        noteHint: 'Un breve contexto nos ayuda a resolver más rápido…',
        contactSupport: 'Contactar soporte',
        storeOpenFallback: apple
            ? 'No se pudo abrir Ajustes. Intenta desde el menú de cuenta del App Store.'
            : 'No se pudo abrir Google Play. Abriendo en el navegador.',
        supportRequestSent: 'Recibimos tu mensaje. Te responderemos pronto.',
        supportRequestFailed:
            'Algo salió mal. Escribe a support@parentledgerinfo.com',
        confirmTitle: apple ? '¿Abrir App Store?' : '¿Abrir Google Play?',
        confirmBody: apple
            ? 'Saldrás de ParentLedger para abrir la gestión de suscripciones de Apple. Allí podrás solicitar un reembolso si aplica.'
            : 'Saldrás de ParentLedger para abrir el centro de suscripciones de Google Play. Allí podrás solicitar un reembolso si aplica.',
        cancel: 'Cancelar',
        continueText: 'Continuar',
        statusCardTitle: 'ESTADO DE LA CUENTA',
        statusLoadError:
            'No se pudieron cargar los detalles de la suscripción.',
        retry: 'Reintentar',
        planFree: 'ParentLedger — nivel gratuito',
        planPremium: 'ParentLedger Premium',
        planPremiumMonthly: 'ParentLedger Premium — mensual',
        planPremiumAnnual: 'ParentLedger Premium — anual',
        planAttorney: 'Acceso profesional (asesoría)',
        renewsOn: (d) => 'Se renueva el $d',
        renewsTrial: (d) => 'Prueba termina · acceso hasta el $d',
        accessEnds: (d) => 'El acceso termina el $d',
        statusTrialing: 'Prueba gratuita',
        statusActive: 'Activa',
        statusFree: 'Gratis',
        statusNoSubscription: 'Sin suscripción activa',
        statusAttorney: 'Incluido en tu espacio de trabajo',
        trialInProgress: 'Prueba en curso',
        trialUsed: 'Oferta intro usada',
      );
}
