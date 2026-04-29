/// Canonical Firestore layout for production case data.
///
/// cases/{caseId}/
///   participants/{userId}
///   conversations/{conversationId}/messages/{messageId}
///   timeline/{eventId}
///   insights/risk          (document id "risk" in subcollection "insights")
///   expenses/{expenseId}
///   exchanges/{exchangeId}
///   exchange_checkins/{checkInId}
///   legalSummaries/{summaryId}
class CasePaths {
  CasePaths._();

  static const String insightsRiskDocId = 'risk';

  /// Default co-parent thread under [conversations].
  static const String defaultConversationId = 'primary';
}
