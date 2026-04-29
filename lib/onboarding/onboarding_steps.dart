/// Firestore `users/{uid}.onboardingStep` values.
abstract final class OnboardingSteps {
  static const String newUser = 'new';
  static const String inviteContext = 'invite_context';
  static const String termsPending = 'terms_pending';
  static const String profileComplete = 'profile_complete';
  static const String coparentInvited = 'coparent_invited';
  static const String childrenAdded = 'children_added';
  static const String subscribed = 'subscribed';
  static const String onboardingComplete = 'onboarding_complete';
}
