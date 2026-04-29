import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../quick_onboarding_prefs.dart';
import 'premium_onboarding_constants.dart';
import 'widgets/premium_glass_badge.dart';
import 'widgets/premium_gradient_background.dart';
import 'widgets/premium_outline_bullet.dart';
import 'widgets/premium_phone_mock.dart';
import 'widgets/premium_primary_button.dart';

/// Four-screen premium pre-auth onboarding → phone signup (no paywall here).
class PremiumOnboardingFlow extends StatefulWidget {
  const PremiumOnboardingFlow({
    super.key,
    required this.initialPage,
    required this.onContinueToPhoneSignup,
  });

  final int initialPage;

  /// Completes guest prefs and navigates to phone / entry (same as Skip).
  final Future<void> Function() onContinueToPhoneSignup;

  @override
  State<PremiumOnboardingFlow> createState() => _PremiumOnboardingFlowState();
}

class _PremiumOnboardingFlowState extends State<PremiumOnboardingFlow> {
  late final PageController _pageController;
  late int _page;

  static const int _pageCount = 4;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, _pageCount - 1);
    _pageController = PageController(initialPage: _page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      QuickOnboardingPrefs.persistStep(_page);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int p) {
    _pageController.animateToPage(
      p,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int p) {
    setState(() => _page = p);
    QuickOnboardingPrefs.persistStep(p);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xff060b18),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: PremiumGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  showBack: _page > 0,
                  onBack: () => _goTo(_page - 1),
                  onSkip: () => unawaited(widget.onContinueToPhoneSignup()),
                  pageIndex: _page,
                  pageCount: _pageCount,
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    itemCount: _pageCount,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: PremiumOnboardingTokens.screenPadding,
                        child: _pages[index],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> get _pages => [
        _HookPage(onNext: () => _goTo(1)),
        _ValuePage(onNext: () => _goTo(2)),
        _TrustPage(onNext: () => _goTo(3)),
        _BridgePage(onStartSetup: widget.onContinueToPhoneSignup),
      ];
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showBack,
    required this.onBack,
    required this.onSkip,
    required this.pageIndex,
    required this.pageCount,
  });

  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final int pageIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: showBack
                ? IconButton(
                    onPressed: onBack,
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: PremiumOnboardingTokens.textSecondary.withValues(alpha: 0.85),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (i) {
                final active = i == pageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 4,
                  width: active ? 22 : 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: active
                        ? const Color(0xff7eb6ff).withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.18),
                  ),
                );
              }),
            ),
          ),
          TextButton(
            onPressed: onSkip,
            child: Text(
              'Skip',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: PremiumOnboardingTokens.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Screen 1 ─────────────────────────────────────────────────────

class _HookPage extends StatelessWidget {
  const _HookPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final headline = PremiumOnboardingTokens.headline(context);
    final subtitle = PremiumOnboardingTokens.subtitle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const PremiumPhoneMockBackdrop(opacity: 0.55),
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Stop arguing about money with your co-parent',
                      style: headline.copyWith(fontSize: 26),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Track expenses, keep records, and protect yourself — all in one place.',
                      style: subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PremiumPrimaryButton(label: 'Get started', onPressed: onNext),
      ],
    );
  }
}

// ─── Screen 2 ───────────────────────────────────────────────────────

class _ValuePage extends StatelessWidget {
  const _ValuePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final headline = PremiumOnboardingTokens.headline(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          'Everything documented.\nNothing forgotten.',
          style: headline.copyWith(fontSize: 26),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 44),
        const PremiumOutlineBullet(
          icon: Icons.flash_on_outlined,
          text: 'Track shared expenses instantly',
        ),
        const PremiumOutlineBullet(
          icon: Icons.gavel_outlined,
          text: 'Keep court-ready records',
        ),
        const PremiumOutlineBullet(
          icon: Icons.timeline_outlined,
          text: 'See everything in one timeline',
        ),
        const Spacer(),
        PremiumPrimaryButton(label: 'Continue', onPressed: onNext),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─── Screen 3 ─────────────────────────────────────────────────────────

class _TrustPage extends StatelessWidget {
  const _TrustPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final headline = PremiumOnboardingTokens.headline(context);
    final subtitle = PremiumOnboardingTokens.subtitle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Center(
          child: PremiumGlassBadge(
            label: 'Court-ready timelines',
            icon: Icons.verified_outlined,
          ),
        ),
        const SizedBox(height: 36),
        Text(
          'Built for real co-parenting situations',
          style: headline.copyWith(fontSize: 26),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        Text(
          'Designed to help you stay organized, reduce conflict, and protect your records.',
          style: subtitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        Text(
          'Organized records · Neutral tone · Built for disputes',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 0.35,
            fontWeight: FontWeight.w600,
            color: PremiumOnboardingTokens.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        const Spacer(),
        PremiumPrimaryButton(label: 'Set up your case', onPressed: onNext),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─── Screen 4 ───────────────────────────────────────────────────────

class _BridgePage extends StatelessWidget {
  const _BridgePage({required this.onStartSetup});

  final Future<void> Function() onStartSetup;

  @override
  Widget build(BuildContext context) {
    final headline = PremiumOnboardingTokens.headline(context);
    final subtitle = PremiumOnboardingTokens.subtitle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          'Let’s set up your case',
          style: headline.copyWith(fontSize: 26),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Text(
          'Takes less than 60 seconds',
          style: subtitle.copyWith(
            fontWeight: FontWeight.w500,
            color: PremiumOnboardingTokens.textSecondary.withValues(alpha: 0.98),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 44),
        _checkLine(Icons.check_circle_outline_rounded, 'Add your child'),
        const SizedBox(height: 22),
        _checkLine(Icons.check_circle_outline_rounded, 'Add co-parent'),
        const SizedBox(height: 22),
        _checkLine(Icons.check_circle_outline_rounded, 'Start tracking'),
        const Spacer(),
        PremiumPrimaryButton(
          label: 'Start setup',
          minimumHeight: 58,
          onPressed: () => unawaited(onStartSetup()),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _checkLine(IconData icon, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 24,
          color: const Color(0xff5eead4).withValues(alpha: 0.95),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.05,
              color: PremiumOnboardingTokens.textPrimary.withValues(alpha: 0.94),
            ),
          ),
        ),
      ],
    );
  }
}
