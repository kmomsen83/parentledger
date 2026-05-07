/// Firestore `users/{uid}.onboardingStep` values.
abstract final class OnboardingSteps {
  /// First step after phone auth: Parent / Attorney ([AccountTypeScreen]).
  static const String accountType = 'account_type';

  /// @deprecated Use [accountType]. Legacy bootstrap value.
  static const String roleSelection = 'role_selection';

  static const String newUser = 'new';
  static const String inviteContext = 'invite_context';
  static const String termsPending = 'terms_pending';
  static const String profileComplete = 'profile_complete';
  static const String coparentInvited = 'coparent_invited';
  static const String childrenAdded = 'children_added';
  static const String subscribed = 'subscribed';
  static const String onboardingComplete = 'onboarding_complete';

  /// Counsel: name / firm / bar before dashboard (`AttorneyOnboardingScreen`).
  static const String attorneyProfile = 'attorney_profile';
}
