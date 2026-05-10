import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'onboarding/onboarding_steps.dart';
import 'providers/case_context.dart';
import 'ui/accept_invite_screen.dart';
import 'ui/invite/accept_invite_screen.dart';
import 'ui/children_list_screen.dart';
import 'ui/attorney/attorney_dashboard_screen.dart';
import 'ui/dashboard_screen.dart';
import 'ui/guest_onboarding_gate.dart';
import 'ui/invite_context_screen.dart';
import 'ui/session_loading_gate.dart';
import 'ui/signup_screen.dart';
import 'ui/paywall_screen.dart';
import 'ui/terms_screen.dart';
import 'ui/workspace_coparent_setup_screen.dart';
import 'ui/enter_invite_code_screen.dart';
import 'ui/onboarding/account_type_screen.dart';
import 'ui/onboarding/attorney_onboarding_screen.dart';

import 'services/invite_link_service.dart';
import 'services/invite_service.dart';
import 'startup_diag.dart';

/// Maps [CaseContext] + invite deep-link state to the correct screen.
/// Does not subscribe to Firestore or RevenueCat; [CaseContext] owns that.
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  String? _pendingInviteId;
  String? _pendingInviteToken;
  String? _pendingInviteCode;
  /// Survives [CaseContext] rebuilds while the accept UI is on screen.
  String? _activeInviteToken;
  VoidCallback? _inviteListener;

  static void _routeLog(String message) {
    developer.log(message, name: 'AppRouterInvite');
  }

  @override
  void initState() {
    super.initState();
    _pendingInviteId = InviteLinkService.pendingInviteId.value;
    _pendingInviteToken = InviteLinkService.pendingInviteToken.value;
    _pendingInviteCode = InviteLinkService.pendingInviteCode.value;
    if (_pendingInviteId != null) {
      InviteService.pendingInviteId = _pendingInviteId;
    }
    if (_pendingInviteToken != null) {
      InviteService.pendingInviteToken = _pendingInviteToken;
    }

    _inviteListener = () {
      final incomingToken = InviteLinkService.pendingInviteToken.value;
      if (incomingToken != null && incomingToken.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _pendingInviteToken = incomingToken;
        });
        InviteService.pendingInviteToken = incomingToken;
        return;
      }
      final incomingCode = InviteLinkService.pendingInviteCode.value;
      if (incomingCode != null && incomingCode.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _pendingInviteCode = incomingCode;
        });
        return;
      }
      final incoming = InviteLinkService.pendingInviteId.value;
      if (incoming == null || incoming.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _pendingInviteId = incoming;
      });
      InviteService.pendingInviteId = incoming;
    };
    InviteLinkService.pendingInviteId.addListener(_inviteListener!);
    InviteLinkService.pendingInviteToken.addListener(_inviteListener!);
    InviteLinkService.pendingInviteCode.addListener(_inviteListener!);
  }

  @override
  void dispose() {
    if (_inviteListener != null) {
      InviteLinkService.pendingInviteId.removeListener(_inviteListener!);
      InviteLinkService.pendingInviteToken.removeListener(_inviteListener!);
      InviteLinkService.pendingInviteCode.removeListener(_inviteListener!);
    }
    super.dispose();
  }

  bool _needsAccountTypeSelection(String step) {
    return step == OnboardingSteps.accountType || step == OnboardingSteps.roleSelection;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();

    if (!session.sessionReadyForRouter) {
      startupDiag(
        'AppRouter.build',
        'BLOCKED → SessionLoadingGate '
        '(authInitializing=${session.authInitializing}, '
        'signedIn=${session.isSignedIn}, '
        'userDocLoading=${session.userDocLoading}, '
        'premiumLoading=${session.premiumLoading})',
      );
      return const SessionLoadingGate();
    }

    startupDiag(
      'AppRouter.build',
      'route branch signedIn=${session.isSignedIn}',
    );

    final hasPendingInvite = _pendingInviteToken != null ||
        _pendingInviteCode != null ||
        _pendingInviteId != null ||
        InviteLinkService.pendingInviteToken.value != null ||
        InviteLinkService.pendingInviteCode.value != null ||
        InviteLinkService.pendingInviteId.value != null;

    if (!session.isSignedIn) {
      return GuestOnboardingGate(hasPendingInvite: hasPendingInvite);
    }

    final step = session.onboardingStep;
    final userDocExists = session.userDocExists;

    if (_activeInviteToken == null &&
        (_pendingInviteToken != null ||
            InviteLinkService.pendingInviteToken.value != null)) {
      final t = _pendingInviteToken ?? InviteLinkService.pendingInviteToken.value;
      if (t != null && t.isNotEmpty) {
        _pendingInviteToken = null;
        InviteLinkService.takePendingInviteToken();
        _activeInviteToken = t;
      }
    }
    if (_activeInviteToken != null && _activeInviteToken!.isNotEmpty) {
      _routeLog('route → AcceptInviteTokenScreen (token)');
      return AcceptInviteTokenScreen(
        token: _activeInviteToken!,
        onFlowFinished: () {
          if (mounted) {
            setState(() => _activeInviteToken = null);
          }
        },
      );
    }
    final pendingCode =
        _pendingInviteCode ?? InviteLinkService.pendingInviteCode.value;
    if (pendingCode != null && pendingCode.isNotEmpty) {
      _pendingInviteCode = null;
      InviteLinkService.takePendingInviteCode();
      _routeLog('route → EnterInviteCodeScreen (shortCode)');
      return EnterInviteCodeScreen(
        initialCode: pendingCode,
        promptConfirmFromDeepLink: true,
      );
    }
    final pendingLegacyId =
        _pendingInviteId ?? InviteLinkService.pendingInviteId.value;
    if (pendingLegacyId != null && pendingLegacyId.isNotEmpty) {
      _pendingInviteId = null;
      InviteLinkService.takePendingInviteId();
      _routeLog('route → AcceptInviteScreen (inviteId)');
      return AcceptInviteScreen(inviteId: pendingLegacyId);
    }

    // --- Account type (Parent vs Attorney) — must run before counsel dashboard ---
    if (_needsAccountTypeSelection(step)) {
      return const AccountTypeScreen();
    }

    // --- Attorney path (never parent custody / children setup) ---
    if (session.isAttorney) {
      if (step == OnboardingSteps.attorneyProfile) {
        return const AttorneyOnboardingScreen();
      }
      return const AttorneyDashboardScreen();
    }

    // --- Parent path ---
    switch (step) {
      case OnboardingSteps.inviteContext:
        return const InviteContextScreen();

      case OnboardingSteps.newUser:
        return const SignupScreen();

      case OnboardingSteps.termsPending:
        return const TermsScreen();

      case OnboardingSteps.profileComplete:
        return const WorkspaceCoparentSetupScreen();

      case OnboardingSteps.coparentInvited:
        return const ChildrenListScreen();

      case OnboardingSteps.childrenAdded:
        return session.hasFullAccess
            ? const DashboardScreen()
            : const PaywallScreen();

      case OnboardingSteps.subscribed:
      case OnboardingSteps.onboardingComplete:
        return const DashboardScreen();

      default:
        if (!userDocExists) {
          return const SignupScreen();
        }
        return const DashboardScreen();
    }
  }
}
