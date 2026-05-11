/// Product-gated surfaces (upgrade sheet, analytics, navigation to paywall).
///
/// Prefer this name in new code; [DashboardPremiumFeature] in
/// `premium_upgrade_sheet.dart` is a typedef alias for backward compatibility.
enum PremiumFeature {
  insightsCluster,
  caseFile,
  parentingReport,
  complianceReports,
  trustEvidence,
  proposals,
  expenseLedger,
  documentsLibrary,
  calendarScheduling,
  compromiseBoard,
}
