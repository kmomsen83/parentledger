/// Free-tier caps: expense creates are **also** enforced by Cloud Function
/// [createCaseExpense] (`FREE_MAX_EXPENSES` in `functions/src/index.ts`) — keep in sync.
class SubscriptionLimits {
  SubscriptionLimits._();

  static const int freeMaxExpenses = 5;

  /// Message-like case timeline rows (Firestore `caseEvents`) on free tier.
  static const int freeMaxTimelineMessageEvents = 10;
}
