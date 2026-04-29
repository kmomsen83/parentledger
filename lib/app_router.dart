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

import 'services/invite_service.dart';
import 'services/invite_link_service.dart';

/// Maps [CaseContext] + invite deep-link state to the correct screen.
/// Does not subscribe to Firestore or RevenueCat; [CaseContext] owns that.
class AppRouter extends StatefulWidget {
  final String? inviteId;

  const AppRouter({super.key, this.inviteId});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  String? pendingInviteId;
  String? pendingInviteToken;
  VoidCallback? _inviteListener;

  @override
  void initState() {
    super.initState();
    pendingInviteId = widget.inviteId;
    if (widget.inviteId != null) {
      InviteService.pendingInviteId = widget.inviteId;
    }
    _inviteListener = () {
      final incomingToken = InviteLinkService.pendingInviteToken.value;
      if (incomingToken != null && incomingToken.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          pendingInviteToken = incomingToken;
        });
        InviteService.pendingInviteToken = incomingToken;
        InviteLinkService.consume();
        return;
      }
      final incoming = InviteLinkService.pendingInviteId.value;
      if (incoming == null || incoming.isEmpty) return;
      if (!mounted) return;
      setState(() {
        pendingInviteId = incoming;
      });
      InviteService.pendingInviteId = incoming;
      InviteLinkService.consume();
    };
    InviteLinkService.pendingInviteId.addListener(_inviteListener!);
    InviteLinkService.pendingInviteToken.addListener(_inviteListener!);
  }

  @override
  void dispose() {
    if (_inviteListener != null) {
      InviteLinkService.pendingInviteId.removeListener(_inviteListener!);
      InviteLinkService.pendingInviteToken.removeListener(_inviteListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();

    if (!session.sessionReadyForRouter) {
      return const SessionLoadingGate();
    }

    if (!session.isSignedIn) {
      return GuestOnboardingGate(inviteId: pendingInviteId);
    }

    final step = session.onboardingStep;
    final userDocExists = session.userDocExists;

    if (pendingInviteId != null) {
      final id = pendingInviteId!;
      pendingInviteId = null;
      return AcceptInviteScreen(inviteId: id);
    }
    final incomingToken = InviteLinkService.pendingInviteToken.value;
    if (incomingToken != null && incomingToken.isNotEmpty) {
      pendingInviteToken = incomingToken;
      InviteService.pendingInviteToken = incomingToken;
      InviteLinkService.consume();
    }
    if (pendingInviteToken != null) {
      final token = pendingInviteToken!;
      pendingInviteToken = null;
      return AcceptInviteTokenScreen(token: token);
    }

    // Attorney (counsel) portal — read-only case tools; not the parent onboarding flow.
    if (session.isAttorney) {
      return const AttorneyDashboardScreen();
    }

    // Order: invite context (invitee) → create account → terms → co-parent → children → paywall → dashboard.
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
