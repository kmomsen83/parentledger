import 'package:flutter/material.dart';

import '../onboarding/premium/premium_onboarding_flow.dart';
import '../onboarding/quick_onboarding_prefs.dart';
import 'entry_screen.dart';

/// Shows the pre-auth onboarding funnel once; then routes to [EntryScreen] (phone signup).
///
/// Invite deep-links skip this funnel so the invitee path stays unchanged.
///
/// Subscription paywall is **not** shown here — see [PaywallScreen] after account setup ([AppRouter]).
class GuestOnboardingGate extends StatefulWidget {
  const GuestOnboardingGate({super.key, this.inviteId});

  final String? inviteId;

  @override
  State<GuestOnboardingGate> createState() => _GuestOnboardingGateState();
}

class _GuestOnboardingGateState extends State<GuestOnboardingGate> {
  bool _loading = true;

  /// Whether to show the emotional funnel (false for invite links or returning users).
  bool _needsQuickOnboarding = true;
  int _startStep = 0;

  @override
  void initState() {
    super.initState();
    if (widget.inviteId != null) {
      _needsQuickOnboarding = false;
      _loading = false;
    } else {
      _loadPrefs();
    }
  }

  Future<void> _loadPrefs() async {
    final done = await QuickOnboardingPrefs.isCompleted();
    final rawStep = await QuickOnboardingPrefs.savedStep();
    if (!mounted) return;
    setState(() {
      _needsQuickOnboarding = !done;
      _startStep = rawStep.clamp(0, 3);
      _loading = false;
    });
  }

  void _openEntry() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EntryScreen(inviteId: widget.inviteId),
      ),
    );
  }

  Future<void> _finishToSignup() async {
    await QuickOnboardingPrefs.markCompleted();
    if (!mounted) return;
    _openEntry();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xff060b18),
        body: const Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (!_needsQuickOnboarding) {
      return EntryScreen(inviteId: widget.inviteId);
    }

    return PremiumOnboardingFlow(
      initialPage: _startStep,
      onContinueToPhoneSignup: _finishToSignup,
    );
  }
}
