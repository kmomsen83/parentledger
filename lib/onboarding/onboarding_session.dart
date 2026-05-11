import '../providers/case_context.dart';
import 'onboarding_steps.dart';

/// Role-aware onboarding routing helpers (single place for step predicates).
abstract final class OnboardingSession {
  static bool stepNeedsRoleSelection(String step) =>
      step == OnboardingSteps.accountType ||
      step == OnboardingSteps.roleSelection;

  /// Attorney identity still in account-type transition or counsel profile wizard.
  static bool attorneyShowsSetupWizard(CaseContext session) {
    if (!session.isAttorney) return false;
    final st = session.onboardingStep;
    return st == OnboardingSteps.accountType ||
        st == OnboardingSteps.roleSelection ||
        st == OnboardingSteps.attorneyProfile;
  }
}
