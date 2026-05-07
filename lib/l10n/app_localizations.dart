import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @startupConnectionIssue_neutral.
  ///
  /// In en, this message translates to:
  /// **'Startup connection issue'**
  String get startupConnectionIssue_neutral;

  /// No description provided for @startupConnectionIssue_professional.
  ///
  /// In en, this message translates to:
  /// **'Startup connection issue'**
  String get startupConnectionIssue_professional;

  /// No description provided for @startupConnectionIssue_legal.
  ///
  /// In en, this message translates to:
  /// **'Startup connection issue'**
  String get startupConnectionIssue_legal;

  /// No description provided for @skip_neutral.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip_neutral;

  /// No description provided for @skip_professional.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip_professional;

  /// No description provided for @skip_legal.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip_legal;

  /// No description provided for @stopArguingAboutMoneyWith_neutral.
  ///
  /// In en, this message translates to:
  /// **'Stop arguing about money with your co-parent'**
  String get stopArguingAboutMoneyWith_neutral;

  /// No description provided for @stopArguingAboutMoneyWith_professional.
  ///
  /// In en, this message translates to:
  /// **'Stop arguing about money with your co-parent'**
  String get stopArguingAboutMoneyWith_professional;

  /// No description provided for @stopArguingAboutMoneyWith_legal.
  ///
  /// In en, this message translates to:
  /// **'Stop arguing about money with your co-parent'**
  String get stopArguingAboutMoneyWith_legal;

  /// No description provided for @trackExpensesKeepRecordsAnd_neutral.
  ///
  /// In en, this message translates to:
  /// **'Track expenses, keep records, and protect yourself — all in one place.'**
  String get trackExpensesKeepRecordsAnd_neutral;

  /// No description provided for @trackExpensesKeepRecordsAnd_professional.
  ///
  /// In en, this message translates to:
  /// **'Track expenses, keep records, and protect yourself — all in one place.'**
  String get trackExpensesKeepRecordsAnd_professional;

  /// No description provided for @trackExpensesKeepRecordsAnd_legal.
  ///
  /// In en, this message translates to:
  /// **'Track expenses, keep records, and protect yourself — all in one place.'**
  String get trackExpensesKeepRecordsAnd_legal;

  /// No description provided for @everythingDocumentednnothingForgotten_neutral.
  ///
  /// In en, this message translates to:
  /// **'Everything documented.\\nNothing forgotten.'**
  String get everythingDocumentednnothingForgotten_neutral;

  /// No description provided for @everythingDocumentednnothingForgotten_professional.
  ///
  /// In en, this message translates to:
  /// **'Everything documented.\\nNothing forgotten.'**
  String get everythingDocumentednnothingForgotten_professional;

  /// No description provided for @everythingDocumentednnothingForgotten_legal.
  ///
  /// In en, this message translates to:
  /// **'Everything documented.\\nNothing forgotten.'**
  String get everythingDocumentednnothingForgotten_legal;

  /// No description provided for @builtForRealCoparentingSituations_neutral.
  ///
  /// In en, this message translates to:
  /// **'Built for real co-parenting situations'**
  String get builtForRealCoparentingSituations_neutral;

  /// No description provided for @builtForRealCoparentingSituations_professional.
  ///
  /// In en, this message translates to:
  /// **'Built for real co-parenting situations'**
  String get builtForRealCoparentingSituations_professional;

  /// No description provided for @builtForRealCoparentingSituations_legal.
  ///
  /// In en, this message translates to:
  /// **'Built for real co-parenting situations'**
  String get builtForRealCoparentingSituations_legal;

  /// No description provided for @designedToHelpYouStay_neutral.
  ///
  /// In en, this message translates to:
  /// **'Designed to help you stay organized, reduce conflict, and protect your records.'**
  String get designedToHelpYouStay_neutral;

  /// No description provided for @designedToHelpYouStay_professional.
  ///
  /// In en, this message translates to:
  /// **'Designed to help you stay organized, reduce conflict, and protect your records.'**
  String get designedToHelpYouStay_professional;

  /// No description provided for @designedToHelpYouStay_legal.
  ///
  /// In en, this message translates to:
  /// **'Designed to help you stay organized, reduce conflict, and protect your records.'**
  String get designedToHelpYouStay_legal;

  /// No description provided for @organizedRecordsNeutralToneBuilt_neutral.
  ///
  /// In en, this message translates to:
  /// **'Organized records · Neutral tone · Built for disputes'**
  String get organizedRecordsNeutralToneBuilt_neutral;

  /// No description provided for @organizedRecordsNeutralToneBuilt_professional.
  ///
  /// In en, this message translates to:
  /// **'Organized records · Neutral tone · Built for disputes'**
  String get organizedRecordsNeutralToneBuilt_professional;

  /// No description provided for @organizedRecordsNeutralToneBuilt_legal.
  ///
  /// In en, this message translates to:
  /// **'Organized records · Neutral tone · Built for disputes'**
  String get organizedRecordsNeutralToneBuilt_legal;

  /// No description provided for @letsSetUpYourCase_neutral.
  ///
  /// In en, this message translates to:
  /// **'Let’s set up your case'**
  String get letsSetUpYourCase_neutral;

  /// No description provided for @letsSetUpYourCase_professional.
  ///
  /// In en, this message translates to:
  /// **'Let’s set up your case'**
  String get letsSetUpYourCase_professional;

  /// No description provided for @letsSetUpYourCase_legal.
  ///
  /// In en, this message translates to:
  /// **'Let’s set up your case'**
  String get letsSetUpYourCase_legal;

  /// No description provided for @takesLessThan60Seconds_neutral.
  ///
  /// In en, this message translates to:
  /// **'Takes less than 60 seconds'**
  String get takesLessThan60Seconds_neutral;

  /// No description provided for @takesLessThan60Seconds_professional.
  ///
  /// In en, this message translates to:
  /// **'Takes less than 60 seconds'**
  String get takesLessThan60Seconds_professional;

  /// No description provided for @takesLessThan60Seconds_legal.
  ///
  /// In en, this message translates to:
  /// **'Takes less than 60 seconds'**
  String get takesLessThan60Seconds_legal;

  /// No description provided for @communicationLog_neutral.
  ///
  /// In en, this message translates to:
  /// **'Communication log'**
  String get communicationLog_neutral;

  /// No description provided for @communicationLog_professional.
  ///
  /// In en, this message translates to:
  /// **'Communication log'**
  String get communicationLog_professional;

  /// No description provided for @communicationLog_legal.
  ///
  /// In en, this message translates to:
  /// **'Communication log'**
  String get communicationLog_legal;

  /// No description provided for @noMessagesInThisExport_neutral.
  ///
  /// In en, this message translates to:
  /// **'No messages in this export.'**
  String get noMessagesInThisExport_neutral;

  /// No description provided for @noMessagesInThisExport_professional.
  ///
  /// In en, this message translates to:
  /// **'No messages in this export.'**
  String get noMessagesInThisExport_professional;

  /// No description provided for @noMessagesInThisExport_legal.
  ///
  /// In en, this message translates to:
  /// **'No messages in this export.'**
  String get noMessagesInThisExport_legal;

  /// No description provided for @couldNotJoinThisWorkspace_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could not join this workspace. The invite may already be used.'**
  String get couldNotJoinThisWorkspace_neutral;

  /// No description provided for @couldNotJoinThisWorkspace_professional.
  ///
  /// In en, this message translates to:
  /// **'Could not join this workspace. The invite may already be used.'**
  String get couldNotJoinThisWorkspace_professional;

  /// No description provided for @couldNotJoinThisWorkspace_legal.
  ///
  /// In en, this message translates to:
  /// **'Could not join this workspace. The invite may already be used.'**
  String get couldNotJoinThisWorkspace_legal;

  /// No description provided for @joinWorkspace_neutral.
  ///
  /// In en, this message translates to:
  /// **'Join workspace'**
  String get joinWorkspace_neutral;

  /// No description provided for @joinWorkspace_professional.
  ///
  /// In en, this message translates to:
  /// **'Join workspace'**
  String get joinWorkspace_professional;

  /// No description provided for @joinWorkspace_legal.
  ///
  /// In en, this message translates to:
  /// **'Join workspace'**
  String get joinWorkspace_legal;

  /// No description provided for @nextYoullConfirmYourProfile_neutral.
  ///
  /// In en, this message translates to:
  /// **'Next you’ll confirm your profile, agree to terms, and review your children. You can add Pro later.'**
  String get nextYoullConfirmYourProfile_neutral;

  /// No description provided for @nextYoullConfirmYourProfile_professional.
  ///
  /// In en, this message translates to:
  /// **'Next you’ll confirm your profile, agree to terms, and review your children. You can add Pro later.'**
  String get nextYoullConfirmYourProfile_professional;

  /// No description provided for @nextYoullConfirmYourProfile_legal.
  ///
  /// In en, this message translates to:
  /// **'Next you’ll confirm your profile, agree to terms, and review your children. You can add Pro later.'**
  String get nextYoullConfirmYourProfile_legal;

  /// No description provided for @noCaseLinkedYetComplete_neutral.
  ///
  /// In en, this message translates to:
  /// **'No case linked yet. Complete setup to see action items.'**
  String get noCaseLinkedYetComplete_neutral;

  /// No description provided for @noCaseLinkedYetComplete_professional.
  ///
  /// In en, this message translates to:
  /// **'No case linked yet. Complete setup to see action items.'**
  String get noCaseLinkedYetComplete_professional;

  /// No description provided for @noCaseLinkedYetComplete_legal.
  ///
  /// In en, this message translates to:
  /// **'No case linked yet. Complete setup to see action items.'**
  String get noCaseLinkedYetComplete_legal;

  /// No description provided for @aiTaggingSuggestionsAreInformational_neutral.
  ///
  /// In en, this message translates to:
  /// **'AI tagging suggestions are informational and should be reviewed before saving.'**
  String get aiTaggingSuggestionsAreInformational_neutral;

  /// No description provided for @aiTaggingSuggestionsAreInformational_professional.
  ///
  /// In en, this message translates to:
  /// **'AI tagging suggestions are informational and should be reviewed before saving.'**
  String get aiTaggingSuggestionsAreInformational_professional;

  /// No description provided for @aiTaggingSuggestionsAreInformational_legal.
  ///
  /// In en, this message translates to:
  /// **'AI tagging suggestions are informational and should be reviewed before saving.'**
  String get aiTaggingSuggestionsAreInformational_legal;

  /// No description provided for @overallFairnessScore_neutral.
  ///
  /// In en, this message translates to:
  /// **'Overall Fairness Score'**
  String get overallFairnessScore_neutral;

  /// No description provided for @overallFairnessScore_professional.
  ///
  /// In en, this message translates to:
  /// **'Overall Fairness Score'**
  String get overallFairnessScore_professional;

  /// No description provided for @overallFairnessScore_legal.
  ///
  /// In en, this message translates to:
  /// **'Overall Fairness Score'**
  String get overallFairnessScore_legal;

  /// No description provided for @msg82_neutral.
  ///
  /// In en, this message translates to:
  /// **'82%'**
  String get msg82_neutral;

  /// No description provided for @msg82_professional.
  ///
  /// In en, this message translates to:
  /// **'82%'**
  String get msg82_professional;

  /// No description provided for @msg82_legal.
  ///
  /// In en, this message translates to:
  /// **'82%'**
  String get msg82_legal;

  /// No description provided for @basedOnRecordedProposalsAnd_neutral.
  ///
  /// In en, this message translates to:
  /// **'Based on recorded proposals and schedule events. Informational only, not legal advice.'**
  String get basedOnRecordedProposalsAnd_neutral;

  /// No description provided for @basedOnRecordedProposalsAnd_professional.
  ///
  /// In en, this message translates to:
  /// **'Based on recorded proposals and schedule events. Informational only, not legal advice.'**
  String get basedOnRecordedProposalsAnd_professional;

  /// No description provided for @basedOnRecordedProposalsAnd_legal.
  ///
  /// In en, this message translates to:
  /// **'Based on recorded proposals and schedule events. Informational only, not legal advice.'**
  String get basedOnRecordedProposalsAnd_legal;

  /// No description provided for @parentingTimeDistribution_neutral.
  ///
  /// In en, this message translates to:
  /// **'Parenting Time Distribution'**
  String get parentingTimeDistribution_neutral;

  /// No description provided for @parentingTimeDistribution_professional.
  ///
  /// In en, this message translates to:
  /// **'Parenting Time Distribution'**
  String get parentingTimeDistribution_professional;

  /// No description provided for @parentingTimeDistribution_legal.
  ///
  /// In en, this message translates to:
  /// **'Parenting Time Distribution'**
  String get parentingTimeDistribution_legal;

  /// No description provided for @aiReasoning_neutral.
  ///
  /// In en, this message translates to:
  /// **'AI Reasoning'**
  String get aiReasoning_neutral;

  /// No description provided for @aiReasoning_professional.
  ///
  /// In en, this message translates to:
  /// **'AI Reasoning'**
  String get aiReasoning_professional;

  /// No description provided for @aiReasoning_legal.
  ///
  /// In en, this message translates to:
  /// **'AI Reasoning'**
  String get aiReasoning_legal;

  /// No description provided for @recentScheduleProposalsIncreasedImbalance_neutral.
  ///
  /// In en, this message translates to:
  /// **'Recent schedule proposals increased imbalance slightly. AI recommends redistributing one weekday overnight to maintain long-term fairness and reduce dispute risk.'**
  String get recentScheduleProposalsIncreasedImbalance_neutral;

  /// No description provided for @recentScheduleProposalsIncreasedImbalance_professional.
  ///
  /// In en, this message translates to:
  /// **'Recent schedule proposals increased imbalance slightly. AI recommends redistributing one weekday overnight to maintain long-term fairness and reduce dispute risk.'**
  String get recentScheduleProposalsIncreasedImbalance_professional;

  /// No description provided for @recentScheduleProposalsIncreasedImbalance_legal.
  ///
  /// In en, this message translates to:
  /// **'Recent schedule proposals increased imbalance slightly. AI recommends redistributing one weekday overnight to maintain long-term fairness and reduce dispute risk.'**
  String get recentScheduleProposalsIncreasedImbalance_legal;

  /// No description provided for @suggestedCompromise_neutral.
  ///
  /// In en, this message translates to:
  /// **'Suggested Compromise'**
  String get suggestedCompromise_neutral;

  /// No description provided for @suggestedCompromise_professional.
  ///
  /// In en, this message translates to:
  /// **'Suggested Compromise'**
  String get suggestedCompromise_professional;

  /// No description provided for @suggestedCompromise_legal.
  ///
  /// In en, this message translates to:
  /// **'Suggested Compromise'**
  String get suggestedCompromise_legal;

  /// No description provided for @transferWednesdayOvernightExchangeTo_neutral.
  ///
  /// In en, this message translates to:
  /// **'Transfer Wednesday overnight exchange to other parent starting next week.'**
  String get transferWednesdayOvernightExchangeTo_neutral;

  /// No description provided for @transferWednesdayOvernightExchangeTo_professional.
  ///
  /// In en, this message translates to:
  /// **'Transfer Wednesday overnight exchange to other parent starting next week.'**
  String get transferWednesdayOvernightExchangeTo_professional;

  /// No description provided for @transferWednesdayOvernightExchangeTo_legal.
  ///
  /// In en, this message translates to:
  /// **'Transfer Wednesday overnight exchange to other parent starting next week.'**
  String get transferWednesdayOvernightExchangeTo_legal;

  /// No description provided for @aiInsightsAreInformationalAnd_neutral.
  ///
  /// In en, this message translates to:
  /// **'AI insights are informational and based on recorded activity.'**
  String get aiInsightsAreInformationalAnd_neutral;

  /// No description provided for @aiInsightsAreInformationalAnd_professional.
  ///
  /// In en, this message translates to:
  /// **'AI insights are informational and based on recorded activity.'**
  String get aiInsightsAreInformationalAnd_professional;

  /// No description provided for @aiInsightsAreInformationalAnd_legal.
  ///
  /// In en, this message translates to:
  /// **'AI insights are informational and based on recorded activity.'**
  String get aiInsightsAreInformationalAnd_legal;

  /// No description provided for @riskLevel_neutral.
  ///
  /// In en, this message translates to:
  /// **'Risk level'**
  String get riskLevel_neutral;

  /// No description provided for @riskLevel_professional.
  ///
  /// In en, this message translates to:
  /// **'Risk level'**
  String get riskLevel_professional;

  /// No description provided for @riskLevel_legal.
  ///
  /// In en, this message translates to:
  /// **'Risk level'**
  String get riskLevel_legal;

  /// No description provided for @informationalOnlyNotLegalAdvice_neutral.
  ///
  /// In en, this message translates to:
  /// **'Informational only — not legal advice. Discuss findings with counsel before relying on them.'**
  String get informationalOnlyNotLegalAdvice_neutral;

  /// No description provided for @informationalOnlyNotLegalAdvice_professional.
  ///
  /// In en, this message translates to:
  /// **'Informational only — not legal advice. Discuss findings with counsel before relying on them.'**
  String get informationalOnlyNotLegalAdvice_professional;

  /// No description provided for @informationalOnlyNotLegalAdvice_legal.
  ///
  /// In en, this message translates to:
  /// **'Informational only — not legal advice. Discuss findings with counsel before relying on them.'**
  String get informationalOnlyNotLegalAdvice_legal;

  /// No description provided for @noComplianceIssuesReported_neutral.
  ///
  /// In en, this message translates to:
  /// **'No compliance issues reported'**
  String get noComplianceIssuesReported_neutral;

  /// No description provided for @noComplianceIssuesReported_professional.
  ///
  /// In en, this message translates to:
  /// **'No compliance issues reported'**
  String get noComplianceIssuesReported_professional;

  /// No description provided for @noComplianceIssuesReported_legal.
  ///
  /// In en, this message translates to:
  /// **'No compliance issues reported'**
  String get noComplianceIssuesReported_legal;

  /// No description provided for @approvingMarksThisAsPaid_neutral.
  ///
  /// In en, this message translates to:
  /// **'Approving marks this as paid. Denying keeps a legal record and marks it denied.'**
  String get approvingMarksThisAsPaid_neutral;

  /// No description provided for @approvingMarksThisAsPaid_professional.
  ///
  /// In en, this message translates to:
  /// **'Approving marks this as paid. Denying keeps a legal record and marks it denied.'**
  String get approvingMarksThisAsPaid_professional;

  /// No description provided for @approvingMarksThisAsPaid_legal.
  ///
  /// In en, this message translates to:
  /// **'Approving marks this as paid. Denying keeps a legal record and marks it denied.'**
  String get approvingMarksThisAsPaid_legal;

  /// No description provided for @caseNotLinked_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case not linked'**
  String get caseNotLinked_neutral;

  /// No description provided for @caseNotLinked_professional.
  ///
  /// In en, this message translates to:
  /// **'Case not linked'**
  String get caseNotLinked_professional;

  /// No description provided for @caseNotLinked_legal.
  ///
  /// In en, this message translates to:
  /// **'Case not linked'**
  String get caseNotLinked_legal;

  /// No description provided for @yourAttorneyProfileMustBe_neutral.
  ///
  /// In en, this message translates to:
  /// **'Your attorney profile must be associated with a custody case before '**
  String get yourAttorneyProfileMustBe_neutral;

  /// No description provided for @yourAttorneyProfileMustBe_professional.
  ///
  /// In en, this message translates to:
  /// **'Your attorney profile must be associated with a custody case before '**
  String get yourAttorneyProfileMustBe_professional;

  /// No description provided for @yourAttorneyProfileMustBe_legal.
  ///
  /// In en, this message translates to:
  /// **'Your attorney profile must be associated with a custody case before '**
  String get yourAttorneyProfileMustBe_legal;

  /// No description provided for @noCaseIsLinkedTo_neutral.
  ///
  /// In en, this message translates to:
  /// **'No case is linked to this attorney profile. '**
  String get noCaseIsLinkedTo_neutral;

  /// No description provided for @noCaseIsLinkedTo_professional.
  ///
  /// In en, this message translates to:
  /// **'No case is linked to this attorney profile. '**
  String get noCaseIsLinkedTo_professional;

  /// No description provided for @noCaseIsLinkedTo_legal.
  ///
  /// In en, this message translates to:
  /// **'No case is linked to this attorney profile. '**
  String get noCaseIsLinkedTo_legal;

  /// No description provided for @readonlyAccessYouCanReview_neutral.
  ///
  /// In en, this message translates to:
  /// **'Read-only access. You can review records and export summaries; '**
  String get readonlyAccessYouCanReview_neutral;

  /// No description provided for @readonlyAccessYouCanReview_professional.
  ///
  /// In en, this message translates to:
  /// **'Read-only access. You can review records and export summaries; '**
  String get readonlyAccessYouCanReview_professional;

  /// No description provided for @readonlyAccessYouCanReview_legal.
  ///
  /// In en, this message translates to:
  /// **'Read-only access. You can review records and export summaries; '**
  String get readonlyAccessYouCanReview_legal;

  /// No description provided for @complianceOverview_neutral.
  ///
  /// In en, this message translates to:
  /// **'Compliance overview'**
  String get complianceOverview_neutral;

  /// No description provided for @complianceOverview_professional.
  ///
  /// In en, this message translates to:
  /// **'Compliance overview'**
  String get complianceOverview_professional;

  /// No description provided for @complianceOverview_legal.
  ///
  /// In en, this message translates to:
  /// **'Compliance overview'**
  String get complianceOverview_legal;

  /// No description provided for @keyFilters_neutral.
  ///
  /// In en, this message translates to:
  /// **'Key filters'**
  String get keyFilters_neutral;

  /// No description provided for @keyFilters_professional.
  ///
  /// In en, this message translates to:
  /// **'Key filters'**
  String get keyFilters_professional;

  /// No description provided for @keyFilters_legal.
  ///
  /// In en, this message translates to:
  /// **'Key filters'**
  String get keyFilters_legal;

  /// No description provided for @alerts_neutral.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts_neutral;

  /// No description provided for @alerts_professional.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts_professional;

  /// No description provided for @alerts_legal.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts_legal;

  /// No description provided for @noRecentComplianceFlagsIn_neutral.
  ///
  /// In en, this message translates to:
  /// **'No recent compliance flags in the pulled timeline.'**
  String get noRecentComplianceFlagsIn_neutral;

  /// No description provided for @noRecentComplianceFlagsIn_professional.
  ///
  /// In en, this message translates to:
  /// **'No recent compliance flags in the pulled timeline.'**
  String get noRecentComplianceFlagsIn_professional;

  /// No description provided for @noRecentComplianceFlagsIn_legal.
  ///
  /// In en, this message translates to:
  /// **'No recent compliance flags in the pulled timeline.'**
  String get noRecentComplianceFlagsIn_legal;

  /// No description provided for @complianceFlag_neutral.
  ///
  /// In en, this message translates to:
  /// **'Compliance flag'**
  String get complianceFlag_neutral;

  /// No description provided for @complianceFlag_professional.
  ///
  /// In en, this message translates to:
  /// **'Compliance flag'**
  String get complianceFlag_professional;

  /// No description provided for @complianceFlag_legal.
  ///
  /// In en, this message translates to:
  /// **'Compliance flag'**
  String get complianceFlag_legal;

  /// No description provided for @documents_neutral.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents_neutral;

  /// No description provided for @documents_professional.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents_professional;

  /// No description provided for @documents_legal.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents_legal;

  /// No description provided for @noMissedOrOverdueExchanges_neutral.
  ///
  /// In en, this message translates to:
  /// **'No missed or overdue exchanges detected in this case record.'**
  String get noMissedOrOverdueExchanges_neutral;

  /// No description provided for @noMissedOrOverdueExchanges_professional.
  ///
  /// In en, this message translates to:
  /// **'No incomplete scheduled exchanges in the current record.'**
  String get noMissedOrOverdueExchanges_professional;

  /// No description provided for @noMissedOrOverdueExchanges_legal.
  ///
  /// In en, this message translates to:
  /// **'No documented failures to complete scheduled exchanges in this matter.'**
  String get noMissedOrOverdueExchanges_legal;

  /// No description provided for @noUnpaidExpensesInThe_neutral.
  ///
  /// In en, this message translates to:
  /// **'No unpaid expenses in the current case record.'**
  String get noUnpaidExpensesInThe_neutral;

  /// No description provided for @noUnpaidExpensesInThe_professional.
  ///
  /// In en, this message translates to:
  /// **'No unpaid expenses in the current case record.'**
  String get noUnpaidExpensesInThe_professional;

  /// No description provided for @noUnpaidExpensesInThe_legal.
  ///
  /// In en, this message translates to:
  /// **'No unpaid expenses in the current case record.'**
  String get noUnpaidExpensesInThe_legal;

  /// No description provided for @linkACustodyCaseIn_neutral.
  ///
  /// In en, this message translates to:
  /// **'Link a custody case in your workspace to use the Case Center.'**
  String get linkACustodyCaseIn_neutral;

  /// No description provided for @linkACustodyCaseIn_professional.
  ///
  /// In en, this message translates to:
  /// **'Link a custody case in your workspace to use the Case Center.'**
  String get linkACustodyCaseIn_professional;

  /// No description provided for @linkACustodyCaseIn_legal.
  ///
  /// In en, this message translates to:
  /// **'Link a custody case in your workspace to use the Case Center.'**
  String get linkACustodyCaseIn_legal;

  /// No description provided for @yourCaseFile_neutral.
  ///
  /// In en, this message translates to:
  /// **'Your case file'**
  String get yourCaseFile_neutral;

  /// No description provided for @yourCaseFile_professional.
  ///
  /// In en, this message translates to:
  /// **'Your case file'**
  String get yourCaseFile_professional;

  /// No description provided for @yourCaseFile_legal.
  ///
  /// In en, this message translates to:
  /// **'Your case file'**
  String get yourCaseFile_legal;

  /// No description provided for @messagesTimelineEvidenceSummariesAnd_neutral.
  ///
  /// In en, this message translates to:
  /// **'Messages, timeline, evidence, summaries, and exports — one place.'**
  String get messagesTimelineEvidenceSummariesAnd_neutral;

  /// No description provided for @messagesTimelineEvidenceSummariesAnd_professional.
  ///
  /// In en, this message translates to:
  /// **'Messages, timeline, evidence, summaries, and exports — one place.'**
  String get messagesTimelineEvidenceSummariesAnd_professional;

  /// No description provided for @messagesTimelineEvidenceSummariesAnd_legal.
  ///
  /// In en, this message translates to:
  /// **'Messages, timeline, evidence, summaries, and exports — one place.'**
  String get messagesTimelineEvidenceSummariesAnd_legal;

  /// No description provided for @buildYourRecord_neutral.
  ///
  /// In en, this message translates to:
  /// **'Build your record'**
  String get buildYourRecord_neutral;

  /// No description provided for @buildYourRecord_professional.
  ///
  /// In en, this message translates to:
  /// **'Build your record'**
  String get buildYourRecord_professional;

  /// No description provided for @buildYourRecord_legal.
  ///
  /// In en, this message translates to:
  /// **'Build your record'**
  String get buildYourRecord_legal;

  /// No description provided for @uploadCourtOrdersAndAgreements_neutral.
  ///
  /// In en, this message translates to:
  /// **'Upload court orders and agreements, capture voice notes, and keep '**
  String get uploadCourtOrdersAndAgreements_neutral;

  /// No description provided for @uploadCourtOrdersAndAgreements_professional.
  ///
  /// In en, this message translates to:
  /// **'Upload court orders and agreements, capture voice notes, and keep '**
  String get uploadCourtOrdersAndAgreements_professional;

  /// No description provided for @uploadCourtOrdersAndAgreements_legal.
  ///
  /// In en, this message translates to:
  /// **'Upload court orders and agreements, capture voice notes, and keep '**
  String get uploadCourtOrdersAndAgreements_legal;

  /// No description provided for @neutralCourtstyleSummary_neutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral, court-style summary'**
  String get neutralCourtstyleSummary_neutral;

  /// No description provided for @neutralCourtstyleSummary_professional.
  ///
  /// In en, this message translates to:
  /// **'Neutral, court-style summary'**
  String get neutralCourtstyleSummary_professional;

  /// No description provided for @neutralCourtstyleSummary_legal.
  ///
  /// In en, this message translates to:
  /// **'Neutral, court-style summary'**
  String get neutralCourtstyleSummary_legal;

  /// No description provided for @pullsFromYourPrimaryMessage_neutral.
  ///
  /// In en, this message translates to:
  /// **'Pulls from your primary message thread, filtered by the dates you choose. '**
  String get pullsFromYourPrimaryMessage_neutral;

  /// No description provided for @pullsFromYourPrimaryMessage_professional.
  ///
  /// In en, this message translates to:
  /// **'Pulls from your primary message thread, filtered by the dates you choose. '**
  String get pullsFromYourPrimaryMessage_professional;

  /// No description provided for @pullsFromYourPrimaryMessage_legal.
  ///
  /// In en, this message translates to:
  /// **'Pulls from your primary message thread, filtered by the dates you choose. '**
  String get pullsFromYourPrimaryMessage_legal;

  /// No description provided for @timestampedAndImmutableRecord_neutral.
  ///
  /// In en, this message translates to:
  /// **'Time-stamped and immutable record'**
  String get timestampedAndImmutableRecord_neutral;

  /// No description provided for @timestampedAndImmutableRecord_professional.
  ///
  /// In en, this message translates to:
  /// **'Time-stamped and immutable record'**
  String get timestampedAndImmutableRecord_professional;

  /// No description provided for @timestampedAndImmutableRecord_legal.
  ///
  /// In en, this message translates to:
  /// **'Time-stamped and immutable record'**
  String get timestampedAndImmutableRecord_legal;

  /// No description provided for @noTimelineEventsYet_neutral.
  ///
  /// In en, this message translates to:
  /// **'No timeline events yet'**
  String get noTimelineEventsYet_neutral;

  /// No description provided for @noTimelineEventsYet_professional.
  ///
  /// In en, this message translates to:
  /// **'No timeline events yet'**
  String get noTimelineEventsYet_professional;

  /// No description provided for @noTimelineEventsYet_legal.
  ///
  /// In en, this message translates to:
  /// **'No timeline events yet'**
  String get noTimelineEventsYet_legal;

  /// No description provided for @messagesExchangesAndExpensesWill_neutral.
  ///
  /// In en, this message translates to:
  /// **'Messages, exchanges, and expenses will appear here as a chronological record.'**
  String get messagesExchangesAndExpensesWill_neutral;

  /// No description provided for @messagesExchangesAndExpensesWill_professional.
  ///
  /// In en, this message translates to:
  /// **'Messages, exchanges, and expenses will appear here as a chronological record.'**
  String get messagesExchangesAndExpensesWill_professional;

  /// No description provided for @messagesExchangesAndExpensesWill_legal.
  ///
  /// In en, this message translates to:
  /// **'Messages, exchanges, and expenses will appear here as a chronological record.'**
  String get messagesExchangesAndExpensesWill_legal;

  /// No description provided for @yourChildren_neutral.
  ///
  /// In en, this message translates to:
  /// **'Your children'**
  String get yourChildren_neutral;

  /// No description provided for @yourChildren_professional.
  ///
  /// In en, this message translates to:
  /// **'Your children'**
  String get yourChildren_professional;

  /// No description provided for @yourChildren_legal.
  ///
  /// In en, this message translates to:
  /// **'Your children'**
  String get yourChildren_legal;

  /// No description provided for @addEachChildOnceYou_neutral.
  ///
  /// In en, this message translates to:
  /// **'Add each child once. You can edit details later from your case.'**
  String get addEachChildOnceYou_neutral;

  /// No description provided for @addEachChildOnceYou_professional.
  ///
  /// In en, this message translates to:
  /// **'Add each child once. You can edit details later from your case.'**
  String get addEachChildOnceYou_professional;

  /// No description provided for @addEachChildOnceYou_legal.
  ///
  /// In en, this message translates to:
  /// **'Add each child once. You can edit details later from your case.'**
  String get addEachChildOnceYou_legal;

  /// No description provided for @continueLabel_neutral.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel_neutral;

  /// No description provided for @continueLabel_professional.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel_professional;

  /// No description provided for @continueLabel_legal.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel_legal;

  /// No description provided for @addAtLeastOneChild_neutral.
  ///
  /// In en, this message translates to:
  /// **'Add at least one child to continue'**
  String get addAtLeastOneChild_neutral;

  /// No description provided for @addAtLeastOneChild_professional.
  ///
  /// In en, this message translates to:
  /// **'Add at least one child to continue'**
  String get addAtLeastOneChild_professional;

  /// No description provided for @addAtLeastOneChild_legal.
  ///
  /// In en, this message translates to:
  /// **'Add at least one child to continue'**
  String get addAtLeastOneChild_legal;

  /// No description provided for @useTheFormAboveYou_neutral.
  ///
  /// In en, this message translates to:
  /// **'Use the form above. You need at least one child on file to finish setup.'**
  String get useTheFormAboveYou_neutral;

  /// No description provided for @useTheFormAboveYou_professional.
  ///
  /// In en, this message translates to:
  /// **'Use the form above. You need at least one child on file to finish setup.'**
  String get useTheFormAboveYou_professional;

  /// No description provided for @useTheFormAboveYou_legal.
  ///
  /// In en, this message translates to:
  /// **'Use the form above. You need at least one child on file to finish setup.'**
  String get useTheFormAboveYou_legal;

  /// No description provided for @overallCompliance_neutral.
  ///
  /// In en, this message translates to:
  /// **'Overall Compliance'**
  String get overallCompliance_neutral;

  /// No description provided for @overallCompliance_professional.
  ///
  /// In en, this message translates to:
  /// **'Overall Compliance'**
  String get overallCompliance_professional;

  /// No description provided for @overallCompliance_legal.
  ///
  /// In en, this message translates to:
  /// **'Overall Compliance'**
  String get overallCompliance_legal;

  /// No description provided for @msg91_neutral.
  ///
  /// In en, this message translates to:
  /// **'91%'**
  String get msg91_neutral;

  /// No description provided for @msg91_professional.
  ///
  /// In en, this message translates to:
  /// **'91%'**
  String get msg91_professional;

  /// No description provided for @msg91_legal.
  ///
  /// In en, this message translates to:
  /// **'91%'**
  String get msg91_legal;

  /// No description provided for @last30Days_neutral.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get last30Days_neutral;

  /// No description provided for @last30Days_professional.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get last30Days_professional;

  /// No description provided for @last30Days_legal.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get last30Days_legal;

  /// No description provided for @thisReportSummarizesDocumentedActivity_neutral.
  ///
  /// In en, this message translates to:
  /// **'This report summarizes documented activity only. It is not legal advice.'**
  String get thisReportSummarizesDocumentedActivity_neutral;

  /// No description provided for @thisReportSummarizesDocumentedActivity_professional.
  ///
  /// In en, this message translates to:
  /// **'This report summarizes documented activity only. It is not legal advice.'**
  String get thisReportSummarizesDocumentedActivity_professional;

  /// No description provided for @thisReportSummarizesDocumentedActivity_legal.
  ///
  /// In en, this message translates to:
  /// **'This report summarizes documented activity only. It is not legal advice.'**
  String get thisReportSummarizesDocumentedActivity_legal;

  /// No description provided for @flaggedEvents_neutral.
  ///
  /// In en, this message translates to:
  /// **'Flagged Events'**
  String get flaggedEvents_neutral;

  /// No description provided for @flaggedEvents_professional.
  ///
  /// In en, this message translates to:
  /// **'Flagged Events'**
  String get flaggedEvents_professional;

  /// No description provided for @flaggedEvents_legal.
  ///
  /// In en, this message translates to:
  /// **'Flagged Events'**
  String get flaggedEvents_legal;

  /// No description provided for @aiNarrativeComplianceRemainsStrong_neutral.
  ///
  /// In en, this message translates to:
  /// **'AI narrative: compliance remains strong. One exchange delay was documented and resolved. Communication tone is trending stable compared to the prior period.'**
  String get aiNarrativeComplianceRemainsStrong_neutral;

  /// No description provided for @aiNarrativeComplianceRemainsStrong_professional.
  ///
  /// In en, this message translates to:
  /// **'AI narrative: compliance remains strong. One exchange delay was documented and resolved. Communication tone is trending stable compared to the prior period.'**
  String get aiNarrativeComplianceRemainsStrong_professional;

  /// No description provided for @aiNarrativeComplianceRemainsStrong_legal.
  ///
  /// In en, this message translates to:
  /// **'AI narrative: compliance remains strong. One exchange delay was documented and resolved. Communication tone is trending stable compared to the prior period.'**
  String get aiNarrativeComplianceRemainsStrong_legal;

  /// No description provided for @reportExportIsAvailableIn_neutral.
  ///
  /// In en, this message translates to:
  /// **'Report export is available in Legal Export Center.'**
  String get reportExportIsAvailableIn_neutral;

  /// No description provided for @reportExportIsAvailableIn_professional.
  ///
  /// In en, this message translates to:
  /// **'Report export is available in Legal Export Center.'**
  String get reportExportIsAvailableIn_professional;

  /// No description provided for @reportExportIsAvailableIn_legal.
  ///
  /// In en, this message translates to:
  /// **'Report export is available in Legal Export Center.'**
  String get reportExportIsAvailableIn_legal;

  /// No description provided for @compromiseHealth_neutral.
  ///
  /// In en, this message translates to:
  /// **'Compromise Health'**
  String get compromiseHealth_neutral;

  /// No description provided for @compromiseHealth_professional.
  ///
  /// In en, this message translates to:
  /// **'Compromise Health'**
  String get compromiseHealth_professional;

  /// No description provided for @compromiseHealth_legal.
  ///
  /// In en, this message translates to:
  /// **'Compromise Health'**
  String get compromiseHealth_legal;

  /// No description provided for @msg76_neutral.
  ///
  /// In en, this message translates to:
  /// **'76%'**
  String get msg76_neutral;

  /// No description provided for @msg76_professional.
  ///
  /// In en, this message translates to:
  /// **'76%'**
  String get msg76_professional;

  /// No description provided for @msg76_legal.
  ///
  /// In en, this message translates to:
  /// **'76%'**
  String get msg76_legal;

  /// No description provided for @useTheseToolsToDeescalate_neutral.
  ///
  /// In en, this message translates to:
  /// **'Use these tools to de-escalate conflict and document constructive resolution.'**
  String get useTheseToolsToDeescalate_neutral;

  /// No description provided for @useTheseToolsToDeescalate_professional.
  ///
  /// In en, this message translates to:
  /// **'Use these tools to de-escalate conflict and document constructive resolution.'**
  String get useTheseToolsToDeescalate_professional;

  /// No description provided for @useTheseToolsToDeescalate_legal.
  ///
  /// In en, this message translates to:
  /// **'Use these tools to de-escalate conflict and document constructive resolution.'**
  String get useTheseToolsToDeescalate_legal;

  /// No description provided for @activeNegotiations_neutral.
  ///
  /// In en, this message translates to:
  /// **'Active Negotiations'**
  String get activeNegotiations_neutral;

  /// No description provided for @activeNegotiations_professional.
  ///
  /// In en, this message translates to:
  /// **'Active Negotiations'**
  String get activeNegotiations_professional;

  /// No description provided for @activeNegotiations_legal.
  ///
  /// In en, this message translates to:
  /// **'Active Negotiations'**
  String get activeNegotiations_legal;

  /// No description provided for @aiInsightRecentProposalAcceptance_neutral.
  ///
  /// In en, this message translates to:
  /// **'AI insight: recent proposal acceptance is improving after neutral, logistics-first messaging. Keep requests specific and time-bound.'**
  String get aiInsightRecentProposalAcceptance_neutral;

  /// No description provided for @aiInsightRecentProposalAcceptance_professional.
  ///
  /// In en, this message translates to:
  /// **'AI insight: recent proposal acceptance is improving after neutral, logistics-first messaging. Keep requests specific and time-bound.'**
  String get aiInsightRecentProposalAcceptance_professional;

  /// No description provided for @aiInsightRecentProposalAcceptance_legal.
  ///
  /// In en, this message translates to:
  /// **'AI insight: recent proposal acceptance is improving after neutral, logistics-first messaging. Keep requests specific and time-bound.'**
  String get aiInsightRecentProposalAcceptance_legal;

  /// No description provided for @generatingCourtSummary_neutral.
  ///
  /// In en, this message translates to:
  /// **'Generating court summary…'**
  String get generatingCourtSummary_neutral;

  /// No description provided for @generatingCourtSummary_professional.
  ///
  /// In en, this message translates to:
  /// **'Generating court summary…'**
  String get generatingCourtSummary_professional;

  /// No description provided for @generatingCourtSummary_legal.
  ///
  /// In en, this message translates to:
  /// **'Generating court summary…'**
  String get generatingCourtSummary_legal;

  /// No description provided for @courtSummaryAi_neutral.
  ///
  /// In en, this message translates to:
  /// **'Court summary (AI)'**
  String get courtSummaryAi_neutral;

  /// No description provided for @courtSummaryAi_professional.
  ///
  /// In en, this message translates to:
  /// **'Court summary (AI)'**
  String get courtSummaryAi_professional;

  /// No description provided for @courtSummaryAi_legal.
  ///
  /// In en, this message translates to:
  /// **'Court summary (AI)'**
  String get courtSummaryAi_legal;

  /// No description provided for @neutralChronologicalOverviewForDocumentation_neutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral, chronological overview for documentation. Not legal advice.'**
  String get neutralChronologicalOverviewForDocumentation_neutral;

  /// No description provided for @neutralChronologicalOverviewForDocumentation_professional.
  ///
  /// In en, this message translates to:
  /// **'Neutral, chronological overview for documentation. Not legal advice.'**
  String get neutralChronologicalOverviewForDocumentation_professional;

  /// No description provided for @neutralChronologicalOverviewForDocumentation_legal.
  ///
  /// In en, this message translates to:
  /// **'Neutral, chronological overview for documentation. Not legal advice.'**
  String get neutralChronologicalOverviewForDocumentation_legal;

  /// No description provided for @courtSummaryCached_neutral.
  ///
  /// In en, this message translates to:
  /// **'Court summary (cached)'**
  String get courtSummaryCached_neutral;

  /// No description provided for @courtSummaryCached_professional.
  ///
  /// In en, this message translates to:
  /// **'Court summary (cached)'**
  String get courtSummaryCached_professional;

  /// No description provided for @courtSummaryCached_legal.
  ///
  /// In en, this message translates to:
  /// **'Court summary (cached)'**
  String get courtSummaryCached_legal;

  /// No description provided for @coparentIsTyping_neutral.
  ///
  /// In en, this message translates to:
  /// **'Co-parent is typing...'**
  String get coparentIsTyping_neutral;

  /// No description provided for @coparentIsTyping_professional.
  ///
  /// In en, this message translates to:
  /// **'Co-parent is typing...'**
  String get coparentIsTyping_professional;

  /// No description provided for @coparentIsTyping_legal.
  ///
  /// In en, this message translates to:
  /// **'Co-parent is typing...'**
  String get coparentIsTyping_legal;

  /// No description provided for @legalMetadata_neutral.
  ///
  /// In en, this message translates to:
  /// **'Legal metadata'**
  String get legalMetadata_neutral;

  /// No description provided for @legalMetadata_professional.
  ///
  /// In en, this message translates to:
  /// **'Legal metadata'**
  String get legalMetadata_professional;

  /// No description provided for @legalMetadata_legal.
  ///
  /// In en, this message translates to:
  /// **'Legal metadata'**
  String get legalMetadata_legal;

  /// No description provided for @messagesCannotBeEditedTags_neutral.
  ///
  /// In en, this message translates to:
  /// **'Messages cannot be edited. Tags and marks build your case record.'**
  String get messagesCannotBeEditedTags_neutral;

  /// No description provided for @messagesCannotBeEditedTags_professional.
  ///
  /// In en, this message translates to:
  /// **'Messages cannot be edited. Tags and marks build your case record.'**
  String get messagesCannotBeEditedTags_professional;

  /// No description provided for @messagesCannotBeEditedTags_legal.
  ///
  /// In en, this message translates to:
  /// **'Messages cannot be edited. Tags and marks build your case record.'**
  String get messagesCannotBeEditedTags_legal;

  /// No description provided for @categories_neutral.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories_neutral;

  /// No description provided for @categories_professional.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories_professional;

  /// No description provided for @categories_legal.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories_legal;

  /// No description provided for @important_neutral.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get important_neutral;

  /// No description provided for @important_professional.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get important_professional;

  /// No description provided for @important_legal.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get important_legal;

  /// No description provided for @evidence_neutral.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get evidence_neutral;

  /// No description provided for @evidence_professional.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get evidence_professional;

  /// No description provided for @evidence_legal.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get evidence_legal;

  /// No description provided for @reviewSuggestedLanguageMayAffect_neutral.
  ///
  /// In en, this message translates to:
  /// **'Review suggested — language may affect your record'**
  String get reviewSuggestedLanguageMayAffect_neutral;

  /// No description provided for @reviewSuggestedLanguageMayAffect_professional.
  ///
  /// In en, this message translates to:
  /// **'Review suggested — language may affect your record'**
  String get reviewSuggestedLanguageMayAffect_professional;

  /// No description provided for @reviewSuggestedLanguageMayAffect_legal.
  ///
  /// In en, this message translates to:
  /// **'Review suggested — language may affect your record'**
  String get reviewSuggestedLanguageMayAffect_legal;

  /// No description provided for @noCaseLinked_neutral.
  ///
  /// In en, this message translates to:
  /// **'No case linked'**
  String get noCaseLinked_neutral;

  /// No description provided for @noCaseLinked_professional.
  ///
  /// In en, this message translates to:
  /// **'No case linked'**
  String get noCaseLinked_professional;

  /// No description provided for @noCaseLinked_legal.
  ///
  /// In en, this message translates to:
  /// **'No case linked'**
  String get noCaseLinked_legal;

  /// No description provided for @connectACustodyCaseIn_neutral.
  ///
  /// In en, this message translates to:
  /// **'Connect a custody case in your workspace before opening the legal message log.'**
  String get connectACustodyCaseIn_neutral;

  /// No description provided for @connectACustodyCaseIn_professional.
  ///
  /// In en, this message translates to:
  /// **'Connect a custody case in your workspace before opening the legal message log.'**
  String get connectACustodyCaseIn_professional;

  /// No description provided for @connectACustodyCaseIn_legal.
  ///
  /// In en, this message translates to:
  /// **'Connect a custody case in your workspace before opening the legal message log.'**
  String get connectACustodyCaseIn_legal;

  /// No description provided for @allMessagesArePermanentlyRecorded_neutral.
  ///
  /// In en, this message translates to:
  /// **'All messages are permanently recorded and may be used in legal documentation.'**
  String get allMessagesArePermanentlyRecorded_neutral;

  /// No description provided for @allMessagesArePermanentlyRecorded_professional.
  ///
  /// In en, this message translates to:
  /// **'All messages are permanently recorded and may be used in legal documentation.'**
  String get allMessagesArePermanentlyRecorded_professional;

  /// No description provided for @allMessagesArePermanentlyRecorded_legal.
  ///
  /// In en, this message translates to:
  /// **'All messages are permanently recorded and may be used in legal documentation.'**
  String get allMessagesArePermanentlyRecorded_legal;

  /// No description provided for @flaggedMessagesRecord_neutral.
  ///
  /// In en, this message translates to:
  /// **'Flagged messages (record)'**
  String get flaggedMessagesRecord_neutral;

  /// No description provided for @flaggedMessagesRecord_professional.
  ///
  /// In en, this message translates to:
  /// **'Flagged messages (review set)'**
  String get flaggedMessagesRecord_professional;

  /// No description provided for @flaggedMessagesRecord_legal.
  ///
  /// In en, this message translates to:
  /// **'Flagged communications (record subset)'**
  String get flaggedMessagesRecord_legal;

  /// No description provided for @message_neutral.
  ///
  /// In en, this message translates to:
  /// **'• '**
  String get message_neutral;

  /// No description provided for @message_professional.
  ///
  /// In en, this message translates to:
  /// **'• '**
  String get message_professional;

  /// No description provided for @message_legal.
  ///
  /// In en, this message translates to:
  /// **'• '**
  String get message_legal;

  /// No description provided for @aiReviewThisMessageMay_neutral.
  ///
  /// In en, this message translates to:
  /// **'AI review: this message may escalate conflict. You can use the suggested wording or send as written.'**
  String get aiReviewThisMessageMay_neutral;

  /// No description provided for @aiReviewThisMessageMay_professional.
  ///
  /// In en, this message translates to:
  /// **'AI review: this message may escalate conflict. You can use the suggested wording or send as written.'**
  String get aiReviewThisMessageMay_professional;

  /// No description provided for @aiReviewThisMessageMay_legal.
  ///
  /// In en, this message translates to:
  /// **'AI review: this message may escalate conflict. You can use the suggested wording or send as written.'**
  String get aiReviewThisMessageMay_legal;

  /// No description provided for @noCoparentConnectedYet_neutral.
  ///
  /// In en, this message translates to:
  /// **'No co-parent connected yet'**
  String get noCoparentConnectedYet_neutral;

  /// No description provided for @noCoparentConnectedYet_professional.
  ///
  /// In en, this message translates to:
  /// **'No co-parent connected yet'**
  String get noCoparentConnectedYet_professional;

  /// No description provided for @noCoparentConnectedYet_legal.
  ///
  /// In en, this message translates to:
  /// **'No co-parent connected yet'**
  String get noCoparentConnectedYet_legal;

  /// No description provided for @messagesAreImmutableOnceSent_neutral.
  ///
  /// In en, this message translates to:
  /// **'Messages are immutable once sent — long-press a bubble to add legal tags.'**
  String get messagesAreImmutableOnceSent_neutral;

  /// No description provided for @messagesAreImmutableOnceSent_professional.
  ///
  /// In en, this message translates to:
  /// **'Messages are immutable once sent — long-press a bubble to add legal tags.'**
  String get messagesAreImmutableOnceSent_professional;

  /// No description provided for @messagesAreImmutableOnceSent_legal.
  ///
  /// In en, this message translates to:
  /// **'Messages are immutable once sent — long-press a bubble to add legal tags.'**
  String get messagesAreImmutableOnceSent_legal;

  /// No description provided for @counselReadonlyYouCannotCompose_neutral.
  ///
  /// In en, this message translates to:
  /// **'Counsel read-only: you cannot compose, edit, or tag messages.'**
  String get counselReadonlyYouCannotCompose_neutral;

  /// No description provided for @counselReadonlyYouCannotCompose_professional.
  ///
  /// In en, this message translates to:
  /// **'Counsel read-only: you cannot compose, edit, or tag messages.'**
  String get counselReadonlyYouCannotCompose_professional;

  /// No description provided for @counselReadonlyYouCannotCompose_legal.
  ///
  /// In en, this message translates to:
  /// **'Counsel read-only: you cannot compose, edit, or tag messages.'**
  String get counselReadonlyYouCannotCompose_legal;

  /// No description provided for @locationSearchIsUnavailableEnter_neutral.
  ///
  /// In en, this message translates to:
  /// **'Location search is unavailable. Enter your address manually.'**
  String get locationSearchIsUnavailableEnter_neutral;

  /// No description provided for @locationSearchIsUnavailableEnter_professional.
  ///
  /// In en, this message translates to:
  /// **'Location search is unavailable. Enter your address manually.'**
  String get locationSearchIsUnavailableEnter_professional;

  /// No description provided for @locationSearchIsUnavailableEnter_legal.
  ///
  /// In en, this message translates to:
  /// **'Location search is unavailable. Enter your address manually.'**
  String get locationSearchIsUnavailableEnter_legal;

  /// No description provided for @couldNotLoadThatPlace_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could not load that place. Try again or enter the address manually.'**
  String get couldNotLoadThatPlace_neutral;

  /// No description provided for @couldNotLoadThatPlace_professional.
  ///
  /// In en, this message translates to:
  /// **'Could not load that place. Try again or enter the address manually.'**
  String get couldNotLoadThatPlace_professional;

  /// No description provided for @couldNotLoadThatPlace_legal.
  ///
  /// In en, this message translates to:
  /// **'Could not load that place. Try again or enter the address manually.'**
  String get couldNotLoadThatPlace_legal;

  /// No description provided for @couldNotVerifyThatAddress_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could not verify that address. Try a fuller street address.'**
  String get couldNotVerifyThatAddress_neutral;

  /// No description provided for @couldNotVerifyThatAddress_professional.
  ///
  /// In en, this message translates to:
  /// **'Could not verify that address. Try a fuller street address.'**
  String get couldNotVerifyThatAddress_professional;

  /// No description provided for @couldNotVerifyThatAddress_legal.
  ///
  /// In en, this message translates to:
  /// **'Could not verify that address. Try a fuller street address.'**
  String get couldNotVerifyThatAddress_legal;

  /// No description provided for @structuredForYourCaseFile_neutral.
  ///
  /// In en, this message translates to:
  /// **'Structured for your case file'**
  String get structuredForYourCaseFile_neutral;

  /// No description provided for @structuredForYourCaseFile_professional.
  ///
  /// In en, this message translates to:
  /// **'Structured for your case file'**
  String get structuredForYourCaseFile_professional;

  /// No description provided for @structuredForYourCaseFile_legal.
  ///
  /// In en, this message translates to:
  /// **'Structured for your case file'**
  String get structuredForYourCaseFile_legal;

  /// No description provided for @noChildrenOnThisCase_neutral.
  ///
  /// In en, this message translates to:
  /// **'No children on this case yet. Add a child in workspace setup.'**
  String get noChildrenOnThisCase_neutral;

  /// No description provided for @noChildrenOnThisCase_professional.
  ///
  /// In en, this message translates to:
  /// **'No children on this case yet. Add a child in workspace setup.'**
  String get noChildrenOnThisCase_professional;

  /// No description provided for @noChildrenOnThisCase_legal.
  ///
  /// In en, this message translates to:
  /// **'No children on this case yet. Add a child in workspace setup.'**
  String get noChildrenOnThisCase_legal;

  /// No description provided for @googlePlacesIsNotConfigured_neutral.
  ///
  /// In en, this message translates to:
  /// **'Google Places is not configured. Build with:\\n'**
  String get googlePlacesIsNotConfigured_neutral;

  /// No description provided for @googlePlacesIsNotConfigured_professional.
  ///
  /// In en, this message translates to:
  /// **'Google Places is not configured. Build with:\\n'**
  String get googlePlacesIsNotConfigured_professional;

  /// No description provided for @googlePlacesIsNotConfigured_legal.
  ///
  /// In en, this message translates to:
  /// **'Google Places is not configured. Build with:\\n'**
  String get googlePlacesIsNotConfigured_legal;

  /// No description provided for @locationVerifiedForLegalRecord_neutral.
  ///
  /// In en, this message translates to:
  /// **'Location verified for legal record'**
  String get locationVerifiedForLegalRecord_neutral;

  /// No description provided for @locationVerifiedForLegalRecord_professional.
  ///
  /// In en, this message translates to:
  /// **'Location verified for legal record'**
  String get locationVerifiedForLegalRecord_professional;

  /// No description provided for @locationVerifiedForLegalRecord_legal.
  ///
  /// In en, this message translates to:
  /// **'Location verified for legal record'**
  String get locationVerifiedForLegalRecord_legal;

  /// No description provided for @placeIdCaptured_neutral.
  ///
  /// In en, this message translates to:
  /// **'Place ID captured'**
  String get placeIdCaptured_neutral;

  /// No description provided for @placeIdCaptured_professional.
  ///
  /// In en, this message translates to:
  /// **'Place ID captured'**
  String get placeIdCaptured_professional;

  /// No description provided for @placeIdCaptured_legal.
  ///
  /// In en, this message translates to:
  /// **'Place ID captured'**
  String get placeIdCaptured_legal;

  /// No description provided for @thisWillBeRecordedIn_neutral.
  ///
  /// In en, this message translates to:
  /// **'This will be recorded in your case timeline'**
  String get thisWillBeRecordedIn_neutral;

  /// No description provided for @thisWillBeRecordedIn_professional.
  ///
  /// In en, this message translates to:
  /// **'This will be recorded in your case timeline'**
  String get thisWillBeRecordedIn_professional;

  /// No description provided for @thisWillBeRecordedIn_legal.
  ///
  /// In en, this message translates to:
  /// **'This will be recorded in your case timeline'**
  String get thisWillBeRecordedIn_legal;

  /// No description provided for @highComplianceConcern_neutral.
  ///
  /// In en, this message translates to:
  /// **'High compliance concern'**
  String get highComplianceConcern_neutral;

  /// No description provided for @highComplianceConcern_professional.
  ///
  /// In en, this message translates to:
  /// **'High compliance concern'**
  String get highComplianceConcern_professional;

  /// No description provided for @highComplianceConcern_legal.
  ///
  /// In en, this message translates to:
  /// **'High compliance concern'**
  String get highComplianceConcern_legal;

  /// No description provided for @complianceFactors_neutral.
  ///
  /// In en, this message translates to:
  /// **'Compliance factors'**
  String get complianceFactors_neutral;

  /// No description provided for @complianceFactors_professional.
  ///
  /// In en, this message translates to:
  /// **'Compliance factors'**
  String get complianceFactors_professional;

  /// No description provided for @complianceFactors_legal.
  ///
  /// In en, this message translates to:
  /// **'Compliance factors'**
  String get complianceFactors_legal;

  /// No description provided for @advancedInsights_neutral.
  ///
  /// In en, this message translates to:
  /// **'Advanced insights'**
  String get advancedInsights_neutral;

  /// No description provided for @advancedInsights_professional.
  ///
  /// In en, this message translates to:
  /// **'Advanced insights'**
  String get advancedInsights_professional;

  /// No description provided for @advancedInsights_legal.
  ///
  /// In en, this message translates to:
  /// **'Advanced insights'**
  String get advancedInsights_legal;

  /// No description provided for @fullHistoryAnalyticsAndPattern_neutral.
  ///
  /// In en, this message translates to:
  /// **'Full history analytics and pattern views are part of ParentLedger Pro.'**
  String get fullHistoryAnalyticsAndPattern_neutral;

  /// No description provided for @fullHistoryAnalyticsAndPattern_professional.
  ///
  /// In en, this message translates to:
  /// **'Full history analytics and pattern views are part of ParentLedger Pro.'**
  String get fullHistoryAnalyticsAndPattern_professional;

  /// No description provided for @fullHistoryAnalyticsAndPattern_legal.
  ///
  /// In en, this message translates to:
  /// **'Full history analytics and pattern views are part of ParentLedger Pro.'**
  String get fullHistoryAnalyticsAndPattern_legal;

  /// No description provided for @insightsTitle_neutral.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle_neutral;

  /// No description provided for @insightsTitle_professional.
  ///
  /// In en, this message translates to:
  /// **'Case insights'**
  String get insightsTitle_professional;

  /// No description provided for @insightsTitle_legal.
  ///
  /// In en, this message translates to:
  /// **'Analytical overview'**
  String get insightsTitle_legal;

  /// No description provided for @saveAProposalToSee_neutral.
  ///
  /// In en, this message translates to:
  /// **'Save a proposal to see fairness scoring on your dashboard.'**
  String get saveAProposalToSee_neutral;

  /// No description provided for @saveAProposalToSee_professional.
  ///
  /// In en, this message translates to:
  /// **'Save a proposal to see fairness scoring on your dashboard.'**
  String get saveAProposalToSee_professional;

  /// No description provided for @saveAProposalToSee_legal.
  ///
  /// In en, this message translates to:
  /// **'Save a proposal to see fairness scoring on your dashboard.'**
  String get saveAProposalToSee_legal;

  /// No description provided for @noComplianceIssuesFlaggedIn_neutral.
  ///
  /// In en, this message translates to:
  /// **'No compliance issues flagged in recent messages.'**
  String get noComplianceIssuesFlaggedIn_neutral;

  /// No description provided for @noComplianceIssuesFlaggedIn_professional.
  ///
  /// In en, this message translates to:
  /// **'No compliance issues flagged in recent messages.'**
  String get noComplianceIssuesFlaggedIn_professional;

  /// No description provided for @noComplianceIssuesFlaggedIn_legal.
  ///
  /// In en, this message translates to:
  /// **'No compliance issues flagged in recent messages.'**
  String get noComplianceIssuesFlaggedIn_legal;

  /// No description provided for @quickPreview_neutral.
  ///
  /// In en, this message translates to:
  /// **'Quick preview'**
  String get quickPreview_neutral;

  /// No description provided for @quickPreview_professional.
  ///
  /// In en, this message translates to:
  /// **'Quick preview'**
  String get quickPreview_professional;

  /// No description provided for @quickPreview_legal.
  ///
  /// In en, this message translates to:
  /// **'Quick preview'**
  String get quickPreview_legal;

  /// No description provided for @tapForFullComplianceScan_neutral.
  ///
  /// In en, this message translates to:
  /// **'Tap for full compliance scan'**
  String get tapForFullComplianceScan_neutral;

  /// No description provided for @tapForFullComplianceScan_professional.
  ///
  /// In en, this message translates to:
  /// **'Tap for full compliance scan'**
  String get tapForFullComplianceScan_professional;

  /// No description provided for @tapForFullComplianceScan_legal.
  ///
  /// In en, this message translates to:
  /// **'Tap for full compliance scan'**
  String get tapForFullComplianceScan_legal;

  /// No description provided for @balance_neutral.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance_neutral;

  /// No description provided for @balance_professional.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance_professional;

  /// No description provided for @balance_legal.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance_legal;

  /// No description provided for @calculating_neutral.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get calculating_neutral;

  /// No description provided for @calculating_professional.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get calculating_professional;

  /// No description provided for @calculating_legal.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get calculating_legal;

  /// No description provided for @caseOverviewEyebrow_neutral.
  ///
  /// In en, this message translates to:
  /// **'CASE OVERVIEW'**
  String get caseOverviewEyebrow_neutral;

  /// No description provided for @caseOverviewEyebrow_professional.
  ///
  /// In en, this message translates to:
  /// **'Case overview'**
  String get caseOverviewEyebrow_professional;

  /// No description provided for @caseOverviewEyebrow_legal.
  ///
  /// In en, this message translates to:
  /// **'MATTER OVERVIEW'**
  String get caseOverviewEyebrow_legal;

  /// No description provided for @courtRecordStatusTitle_neutral.
  ///
  /// In en, this message translates to:
  /// **'Court Record Status'**
  String get courtRecordStatusTitle_neutral;

  /// No description provided for @courtRecordStatusTitle_professional.
  ///
  /// In en, this message translates to:
  /// **'Record status'**
  String get courtRecordStatusTitle_professional;

  /// No description provided for @courtRecordStatusTitle_legal.
  ///
  /// In en, this message translates to:
  /// **'Matter record status'**
  String get courtRecordStatusTitle_legal;

  /// No description provided for @scoreReflectsDocumentedActivityAnd_neutral.
  ///
  /// In en, this message translates to:
  /// **'Score reflects documented activity and communication patterns. Not a legal determination.'**
  String get scoreReflectsDocumentedActivityAnd_neutral;

  /// No description provided for @scoreReflectsDocumentedActivityAnd_professional.
  ///
  /// In en, this message translates to:
  /// **'Score reflects documented activity and communication patterns. Not a legal determination.'**
  String get scoreReflectsDocumentedActivityAnd_professional;

  /// No description provided for @scoreReflectsDocumentedActivityAnd_legal.
  ///
  /// In en, this message translates to:
  /// **'Score reflects documented activity and communication patterns. Not a legal determination.'**
  String get scoreReflectsDocumentedActivityAnd_legal;

  /// No description provided for @messages_neutral.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages_neutral;

  /// No description provided for @messages_professional.
  ///
  /// In en, this message translates to:
  /// **'Case messages'**
  String get messages_professional;

  /// No description provided for @messages_legal.
  ///
  /// In en, this message translates to:
  /// **'Communication log (case file)'**
  String get messages_legal;

  /// No description provided for @linkACaseToUse_neutral.
  ///
  /// In en, this message translates to:
  /// **'Link a case to use messages'**
  String get linkACaseToUse_neutral;

  /// No description provided for @linkACaseToUse_professional.
  ///
  /// In en, this message translates to:
  /// **'Link a case to use messages'**
  String get linkACaseToUse_professional;

  /// No description provided for @linkACaseToUse_legal.
  ///
  /// In en, this message translates to:
  /// **'Link a case to use messages'**
  String get linkACaseToUse_legal;

  /// No description provided for @caseFileRecords_neutral.
  ///
  /// In en, this message translates to:
  /// **'CASE FILE & RECORDS'**
  String get caseFileRecords_neutral;

  /// No description provided for @caseFileRecords_professional.
  ///
  /// In en, this message translates to:
  /// **'CASE FILE & RECORDS'**
  String get caseFileRecords_professional;

  /// No description provided for @caseFileRecords_legal.
  ///
  /// In en, this message translates to:
  /// **'CASE FILE & RECORDS'**
  String get caseFileRecords_legal;

  /// No description provided for @eliteWorkspace_neutral.
  ///
  /// In en, this message translates to:
  /// **'Elite workspace'**
  String get eliteWorkspace_neutral;

  /// No description provided for @eliteWorkspace_professional.
  ///
  /// In en, this message translates to:
  /// **'Elite workspace'**
  String get eliteWorkspace_professional;

  /// No description provided for @eliteWorkspace_legal.
  ///
  /// In en, this message translates to:
  /// **'Elite workspace'**
  String get eliteWorkspace_legal;

  /// No description provided for @courtExportsLiveExpensesActivity_neutral.
  ///
  /// In en, this message translates to:
  /// **'Court exports · live expenses · activity · child profiles'**
  String get courtExportsLiveExpensesActivity_neutral;

  /// No description provided for @courtExportsLiveExpensesActivity_professional.
  ///
  /// In en, this message translates to:
  /// **'Court exports · live expenses · activity · child profiles'**
  String get courtExportsLiveExpensesActivity_professional;

  /// No description provided for @courtExportsLiveExpensesActivity_legal.
  ///
  /// In en, this message translates to:
  /// **'Court exports · live expenses · activity · child profiles'**
  String get courtExportsLiveExpensesActivity_legal;

  /// No description provided for @caseOverview_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case overview'**
  String get caseOverview_neutral;

  /// No description provided for @caseOverview_professional.
  ///
  /// In en, this message translates to:
  /// **'Case overview'**
  String get caseOverview_professional;

  /// No description provided for @caseOverview_legal.
  ///
  /// In en, this message translates to:
  /// **'Case overview'**
  String get caseOverview_legal;

  /// No description provided for @documentType_neutral.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get documentType_neutral;

  /// No description provided for @documentType_professional.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get documentType_professional;

  /// No description provided for @documentType_legal.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get documentType_legal;

  /// No description provided for @noCaseLinkedCompleteSetup_neutral.
  ///
  /// In en, this message translates to:
  /// **'No case linked. Complete setup to manage documents.'**
  String get noCaseLinkedCompleteSetup_neutral;

  /// No description provided for @noCaseLinkedCompleteSetup_professional.
  ///
  /// In en, this message translates to:
  /// **'No case linked. Complete setup to manage documents.'**
  String get noCaseLinkedCompleteSetup_professional;

  /// No description provided for @noCaseLinkedCompleteSetup_legal.
  ///
  /// In en, this message translates to:
  /// **'No case linked. Complete setup to manage documents.'**
  String get noCaseLinkedCompleteSetup_legal;

  /// No description provided for @noDocumentsYet_neutral.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get noDocumentsYet_neutral;

  /// No description provided for @noDocumentsYet_professional.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get noDocumentsYet_professional;

  /// No description provided for @noDocumentsYet_legal.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get noDocumentsYet_legal;

  /// No description provided for @uploadCourtOrdersAgreementsOr_neutral.
  ///
  /// In en, this message translates to:
  /// **'Upload court orders, agreements, or evidence files. '**
  String get uploadCourtOrdersAgreementsOr_neutral;

  /// No description provided for @uploadCourtOrdersAgreementsOr_professional.
  ///
  /// In en, this message translates to:
  /// **'Upload court orders, agreements, or evidence files. '**
  String get uploadCourtOrdersAgreementsOr_professional;

  /// No description provided for @uploadCourtOrdersAgreementsOr_legal.
  ///
  /// In en, this message translates to:
  /// **'Upload court orders, agreements, or evidence files. '**
  String get uploadCourtOrdersAgreementsOr_legal;

  /// No description provided for @caseFile_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case file'**
  String get caseFile_neutral;

  /// No description provided for @caseFile_professional.
  ///
  /// In en, this message translates to:
  /// **'Case file'**
  String get caseFile_professional;

  /// No description provided for @caseFile_legal.
  ///
  /// In en, this message translates to:
  /// **'Case file'**
  String get caseFile_legal;

  /// No description provided for @productionRecords_neutral.
  ///
  /// In en, this message translates to:
  /// **'PRODUCTION RECORDS'**
  String get productionRecords_neutral;

  /// No description provided for @productionRecords_professional.
  ///
  /// In en, this message translates to:
  /// **'PRODUCTION RECORDS'**
  String get productionRecords_professional;

  /// No description provided for @productionRecords_legal.
  ///
  /// In en, this message translates to:
  /// **'PRODUCTION RECORDS'**
  String get productionRecords_legal;

  /// No description provided for @completeWorkspaceSetupSoYour_neutral.
  ///
  /// In en, this message translates to:
  /// **'Complete workspace setup so your case is linked.'**
  String get completeWorkspaceSetupSoYour_neutral;

  /// No description provided for @completeWorkspaceSetupSoYour_professional.
  ///
  /// In en, this message translates to:
  /// **'Complete workspace setup so your case is linked.'**
  String get completeWorkspaceSetupSoYour_professional;

  /// No description provided for @completeWorkspaceSetupSoYour_legal.
  ///
  /// In en, this message translates to:
  /// **'Complete workspace setup so your case is linked.'**
  String get completeWorkspaceSetupSoYour_legal;

  /// No description provided for @children_neutral.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children_neutral;

  /// No description provided for @children_professional.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children_professional;

  /// No description provided for @children_legal.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get children_legal;

  /// No description provided for @linkYourWorkspaceToSee_neutral.
  ///
  /// In en, this message translates to:
  /// **'Link your workspace to see children on this case.'**
  String get linkYourWorkspaceToSee_neutral;

  /// No description provided for @linkYourWorkspaceToSee_professional.
  ///
  /// In en, this message translates to:
  /// **'Link your workspace to see children on this case.'**
  String get linkYourWorkspaceToSee_professional;

  /// No description provided for @linkYourWorkspaceToSee_legal.
  ///
  /// In en, this message translates to:
  /// **'Link your workspace to see children on this case.'**
  String get linkYourWorkspaceToSee_legal;

  /// No description provided for @couldNotLoadChildren_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could not load children.'**
  String get couldNotLoadChildren_neutral;

  /// No description provided for @couldNotLoadChildren_professional.
  ///
  /// In en, this message translates to:
  /// **'Could not load children.'**
  String get couldNotLoadChildren_professional;

  /// No description provided for @couldNotLoadChildren_legal.
  ///
  /// In en, this message translates to:
  /// **'Could not load children.'**
  String get couldNotLoadChildren_legal;

  /// No description provided for @noChildrenAddedYetAdd_neutral.
  ///
  /// In en, this message translates to:
  /// **'No children added yet. Add a child from your profile / onboarding.'**
  String get noChildrenAddedYetAdd_neutral;

  /// No description provided for @noChildrenAddedYetAdd_professional.
  ///
  /// In en, this message translates to:
  /// **'No children added yet. Add a child from your profile / onboarding.'**
  String get noChildrenAddedYetAdd_professional;

  /// No description provided for @noChildrenAddedYetAdd_legal.
  ///
  /// In en, this message translates to:
  /// **'No children added yet. Add a child from your profile / onboarding.'**
  String get noChildrenAddedYetAdd_legal;

  /// No description provided for @recordCopiedPasteIntoEmail_neutral.
  ///
  /// In en, this message translates to:
  /// **'Record copied — paste into email, cloud storage, or counsel.'**
  String get recordCopiedPasteIntoEmail_neutral;

  /// No description provided for @recordCopiedPasteIntoEmail_professional.
  ///
  /// In en, this message translates to:
  /// **'Record copied — paste into email, cloud storage, or counsel.'**
  String get recordCopiedPasteIntoEmail_professional;

  /// No description provided for @recordCopiedPasteIntoEmail_legal.
  ///
  /// In en, this message translates to:
  /// **'Record copied — paste into email, cloud storage, or counsel.'**
  String get recordCopiedPasteIntoEmail_legal;

  /// No description provided for @checkinRecorded_neutral.
  ///
  /// In en, this message translates to:
  /// **'Check-In Recorded'**
  String get checkinRecorded_neutral;

  /// No description provided for @checkinRecorded_professional.
  ///
  /// In en, this message translates to:
  /// **'Check-In Recorded'**
  String get checkinRecorded_professional;

  /// No description provided for @checkinRecorded_legal.
  ///
  /// In en, this message translates to:
  /// **'Check-In Recorded'**
  String get checkinRecorded_legal;

  /// No description provided for @thisRecordIsSecurelyStored_neutral.
  ///
  /// In en, this message translates to:
  /// **'This record is securely stored and cannot be edited.'**
  String get thisRecordIsSecurelyStored_neutral;

  /// No description provided for @thisRecordIsSecurelyStored_professional.
  ///
  /// In en, this message translates to:
  /// **'This record is securely stored and cannot be edited.'**
  String get thisRecordIsSecurelyStored_professional;

  /// No description provided for @thisRecordIsSecurelyStored_legal.
  ///
  /// In en, this message translates to:
  /// **'This record is securely stored and cannot be edited.'**
  String get thisRecordIsSecurelyStored_legal;

  /// No description provided for @summary_neutral.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary_neutral;

  /// No description provided for @summary_professional.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary_professional;

  /// No description provided for @summary_legal.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary_legal;

  /// No description provided for @timestamp_neutral.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp_neutral;

  /// No description provided for @timestamp_professional.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp_professional;

  /// No description provided for @timestamp_legal.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp_legal;

  /// No description provided for @address_neutral.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address_neutral;

  /// No description provided for @address_professional.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address_professional;

  /// No description provided for @address_legal.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address_legal;

  /// No description provided for @gpsCoordinates_neutral.
  ///
  /// In en, this message translates to:
  /// **'GPS coordinates'**
  String get gpsCoordinates_neutral;

  /// No description provided for @gpsCoordinates_professional.
  ///
  /// In en, this message translates to:
  /// **'GPS coordinates'**
  String get gpsCoordinates_professional;

  /// No description provided for @gpsCoordinates_legal.
  ///
  /// In en, this message translates to:
  /// **'GPS coordinates'**
  String get gpsCoordinates_legal;

  /// No description provided for @eachParentMayCompleteTheir_neutral.
  ///
  /// In en, this message translates to:
  /// **'Each parent may complete their own check-in for the same exchange. '**
  String get eachParentMayCompleteTheir_neutral;

  /// No description provided for @eachParentMayCompleteTheir_professional.
  ///
  /// In en, this message translates to:
  /// **'Each parent may complete their own check-in for the same exchange. '**
  String get eachParentMayCompleteTheir_professional;

  /// No description provided for @eachParentMayCompleteTheir_legal.
  ///
  /// In en, this message translates to:
  /// **'Each parent may complete their own check-in for the same exchange. '**
  String get eachParentMayCompleteTheir_legal;

  /// No description provided for @noScheduledExchange_neutral.
  ///
  /// In en, this message translates to:
  /// **'No scheduled exchange'**
  String get noScheduledExchange_neutral;

  /// No description provided for @noScheduledExchange_professional.
  ///
  /// In en, this message translates to:
  /// **'No scheduled exchange'**
  String get noScheduledExchange_professional;

  /// No description provided for @noScheduledExchange_legal.
  ///
  /// In en, this message translates to:
  /// **'No scheduled exchange'**
  String get noScheduledExchange_legal;

  /// No description provided for @youCanStillLogA_neutral.
  ///
  /// In en, this message translates to:
  /// **'You can still log a time-stamped custody exchange with GPS, '**
  String get youCanStillLogA_neutral;

  /// No description provided for @youCanStillLogA_professional.
  ///
  /// In en, this message translates to:
  /// **'You can still log a time-stamped custody exchange with GPS, '**
  String get youCanStillLogA_professional;

  /// No description provided for @youCanStillLogA_legal.
  ///
  /// In en, this message translates to:
  /// **'You can still log a time-stamped custody exchange with GPS, '**
  String get youCanStillLogA_legal;

  /// No description provided for @upcomingExchange_neutral.
  ///
  /// In en, this message translates to:
  /// **'Upcoming exchange'**
  String get upcomingExchange_neutral;

  /// No description provided for @upcomingExchange_professional.
  ///
  /// In en, this message translates to:
  /// **'Upcoming exchange'**
  String get upcomingExchange_professional;

  /// No description provided for @upcomingExchange_legal.
  ///
  /// In en, this message translates to:
  /// **'Upcoming exchange'**
  String get upcomingExchange_legal;

  /// No description provided for @reviewDetails_neutral.
  ///
  /// In en, this message translates to:
  /// **'Review details'**
  String get reviewDetails_neutral;

  /// No description provided for @reviewDetails_professional.
  ///
  /// In en, this message translates to:
  /// **'Review details'**
  String get reviewDetails_professional;

  /// No description provided for @reviewDetails_legal.
  ///
  /// In en, this message translates to:
  /// **'Review details'**
  String get reviewDetails_legal;

  /// No description provided for @locationUnavailable_neutral.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get locationUnavailable_neutral;

  /// No description provided for @locationUnavailable_professional.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get locationUnavailable_professional;

  /// No description provided for @locationUnavailable_legal.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get locationUnavailable_legal;

  /// No description provided for @youAreNotAtThe_neutral.
  ///
  /// In en, this message translates to:
  /// **'You are not at the exchange location'**
  String get youAreNotAtThe_neutral;

  /// No description provided for @youAreNotAtThe_professional.
  ///
  /// In en, this message translates to:
  /// **'You are not at the exchange location'**
  String get youAreNotAtThe_professional;

  /// No description provided for @youAreNotAtThe_legal.
  ///
  /// In en, this message translates to:
  /// **'You are not at the exchange location'**
  String get youAreNotAtThe_legal;

  /// No description provided for @youAreAtTheExchange_neutral.
  ///
  /// In en, this message translates to:
  /// **'You are at the exchange location'**
  String get youAreAtTheExchange_neutral;

  /// No description provided for @youAreAtTheExchange_professional.
  ///
  /// In en, this message translates to:
  /// **'You are at the exchange location'**
  String get youAreAtTheExchange_professional;

  /// No description provided for @youAreAtTheExchange_legal.
  ///
  /// In en, this message translates to:
  /// **'You are at the exchange location'**
  String get youAreAtTheExchange_legal;

  /// No description provided for @manualCheckin_neutral.
  ///
  /// In en, this message translates to:
  /// **'Manual check-in'**
  String get manualCheckin_neutral;

  /// No description provided for @manualCheckin_professional.
  ///
  /// In en, this message translates to:
  /// **'Manual check-in'**
  String get manualCheckin_professional;

  /// No description provided for @manualCheckin_legal.
  ///
  /// In en, this message translates to:
  /// **'Manual check-in'**
  String get manualCheckin_legal;

  /// No description provided for @weWillCaptureGpsOptional_neutral.
  ///
  /// In en, this message translates to:
  /// **'We will capture GPS, optional photo, and note. The entry is permanent.'**
  String get weWillCaptureGpsOptional_neutral;

  /// No description provided for @weWillCaptureGpsOptional_professional.
  ///
  /// In en, this message translates to:
  /// **'We will capture GPS, optional photo, and note. The entry is permanent.'**
  String get weWillCaptureGpsOptional_professional;

  /// No description provided for @weWillCaptureGpsOptional_legal.
  ///
  /// In en, this message translates to:
  /// **'We will capture GPS, optional photo, and note. The entry is permanent.'**
  String get weWillCaptureGpsOptional_legal;

  /// No description provided for @capturingGps_neutral.
  ///
  /// In en, this message translates to:
  /// **'Capturing GPS…'**
  String get capturingGps_neutral;

  /// No description provided for @capturingGps_professional.
  ///
  /// In en, this message translates to:
  /// **'Capturing GPS…'**
  String get capturingGps_professional;

  /// No description provided for @capturingGps_legal.
  ///
  /// In en, this message translates to:
  /// **'Capturing GPS…'**
  String get capturingGps_legal;

  /// No description provided for @holdSteadyForAFew_neutral.
  ///
  /// In en, this message translates to:
  /// **'Hold steady for a few seconds.'**
  String get holdSteadyForAFew_neutral;

  /// No description provided for @holdSteadyForAFew_professional.
  ///
  /// In en, this message translates to:
  /// **'Hold steady for a few seconds.'**
  String get holdSteadyForAFew_professional;

  /// No description provided for @holdSteadyForAFew_legal.
  ///
  /// In en, this message translates to:
  /// **'Hold steady for a few seconds.'**
  String get holdSteadyForAFew_legal;

  /// No description provided for @activeCheckin_neutral.
  ///
  /// In en, this message translates to:
  /// **'Active check-in'**
  String get activeCheckin_neutral;

  /// No description provided for @activeCheckin_professional.
  ///
  /// In en, this message translates to:
  /// **'Active check-in'**
  String get activeCheckin_professional;

  /// No description provided for @activeCheckin_legal.
  ///
  /// In en, this message translates to:
  /// **'Active check-in'**
  String get activeCheckin_legal;

  /// No description provided for @liveTime_neutral.
  ///
  /// In en, this message translates to:
  /// **'Live time'**
  String get liveTime_neutral;

  /// No description provided for @liveTime_professional.
  ///
  /// In en, this message translates to:
  /// **'Live time'**
  String get liveTime_professional;

  /// No description provided for @liveTime_legal.
  ///
  /// In en, this message translates to:
  /// **'Live time'**
  String get liveTime_legal;

  /// No description provided for @noMapPreview_neutral.
  ///
  /// In en, this message translates to:
  /// **'No map preview'**
  String get noMapPreview_neutral;

  /// No description provided for @noMapPreview_professional.
  ///
  /// In en, this message translates to:
  /// **'No map preview'**
  String get noMapPreview_professional;

  /// No description provided for @noMapPreview_legal.
  ///
  /// In en, this message translates to:
  /// **'No map preview'**
  String get noMapPreview_legal;

  /// No description provided for @submittingCreatesAnImmutableRecord_neutral.
  ///
  /// In en, this message translates to:
  /// **'Submitting creates an immutable record with server time, device context, and integrity hash.'**
  String get submittingCreatesAnImmutableRecord_neutral;

  /// No description provided for @submittingCreatesAnImmutableRecord_professional.
  ///
  /// In en, this message translates to:
  /// **'Submitting creates an immutable record with server time, device context, and integrity hash.'**
  String get submittingCreatesAnImmutableRecord_professional;

  /// No description provided for @submittingCreatesAnImmutableRecord_legal.
  ///
  /// In en, this message translates to:
  /// **'Submitting creates an immutable record with server time, device context, and integrity hash.'**
  String get submittingCreatesAnImmutableRecord_legal;

  /// No description provided for @exchangeScheduled_neutral.
  ///
  /// In en, this message translates to:
  /// **'Exchange Scheduled'**
  String get exchangeScheduled_neutral;

  /// No description provided for @exchangeScheduled_professional.
  ///
  /// In en, this message translates to:
  /// **'Exchange Scheduled'**
  String get exchangeScheduled_professional;

  /// No description provided for @exchangeScheduled_legal.
  ///
  /// In en, this message translates to:
  /// **'Exchange Scheduled'**
  String get exchangeScheduled_legal;

  /// No description provided for @thisExchangeIsOnYour_neutral.
  ///
  /// In en, this message translates to:
  /// **'This exchange is on your case file with a server time stamp.'**
  String get thisExchangeIsOnYour_neutral;

  /// No description provided for @thisExchangeIsOnYour_professional.
  ///
  /// In en, this message translates to:
  /// **'This exchange is on your case file with a server time stamp.'**
  String get thisExchangeIsOnYour_professional;

  /// No description provided for @thisExchangeIsOnYour_legal.
  ///
  /// In en, this message translates to:
  /// **'This exchange is on your case file with a server time stamp.'**
  String get thisExchangeIsOnYour_legal;

  /// No description provided for @date_neutral.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date_neutral;

  /// No description provided for @date_professional.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date_professional;

  /// No description provided for @date_legal.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date_legal;

  /// No description provided for @time_neutral.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time_neutral;

  /// No description provided for @time_professional.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time_professional;

  /// No description provided for @time_legal.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time_legal;

  /// No description provided for @location_neutral.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location_neutral;

  /// No description provided for @location_professional.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location_professional;

  /// No description provided for @location_legal.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location_legal;

  /// No description provided for @noCaseLinkedCompleteWorkspace_neutral.
  ///
  /// In en, this message translates to:
  /// **'No case linked. Complete workspace setup to track expenses.'**
  String get noCaseLinkedCompleteWorkspace_neutral;

  /// No description provided for @noCaseLinkedCompleteWorkspace_professional.
  ///
  /// In en, this message translates to:
  /// **'No case linked. Complete workspace setup to track expenses.'**
  String get noCaseLinkedCompleteWorkspace_professional;

  /// No description provided for @noCaseLinkedCompleteWorkspace_legal.
  ///
  /// In en, this message translates to:
  /// **'No case linked. Complete workspace setup to track expenses.'**
  String get noCaseLinkedCompleteWorkspace_legal;

  /// No description provided for @noExpensesYet_neutral.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get noExpensesYet_neutral;

  /// No description provided for @noExpensesYet_professional.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get noExpensesYet_professional;

  /// No description provided for @noExpensesYet_legal.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get noExpensesYet_legal;

  /// No description provided for @startTrackingSharedCostsWith_neutral.
  ///
  /// In en, this message translates to:
  /// **'Start tracking shared costs with your co-parent.'**
  String get startTrackingSharedCostsWith_neutral;

  /// No description provided for @startTrackingSharedCostsWith_professional.
  ///
  /// In en, this message translates to:
  /// **'Start tracking shared costs with your co-parent.'**
  String get startTrackingSharedCostsWith_professional;

  /// No description provided for @startTrackingSharedCostsWith_legal.
  ///
  /// In en, this message translates to:
  /// **'Start tracking shared costs with your co-parent.'**
  String get startTrackingSharedCostsWith_legal;

  /// No description provided for @financialIntelligence_neutral.
  ///
  /// In en, this message translates to:
  /// **'Financial intelligence'**
  String get financialIntelligence_neutral;

  /// No description provided for @financialIntelligence_professional.
  ///
  /// In en, this message translates to:
  /// **'Financial intelligence'**
  String get financialIntelligence_professional;

  /// No description provided for @financialIntelligence_legal.
  ///
  /// In en, this message translates to:
  /// **'Financial intelligence'**
  String get financialIntelligence_legal;

  /// No description provided for @linkYourCaseToSee_neutral.
  ///
  /// In en, this message translates to:
  /// **'Link your case to see shared expenses.'**
  String get linkYourCaseToSee_neutral;

  /// No description provided for @linkYourCaseToSee_professional.
  ///
  /// In en, this message translates to:
  /// **'Link your case to see shared expenses.'**
  String get linkYourCaseToSee_professional;

  /// No description provided for @linkYourCaseToSee_legal.
  ///
  /// In en, this message translates to:
  /// **'Link your case to see shared expenses.'**
  String get linkYourCaseToSee_legal;

  /// No description provided for @couldNotLoadExpenses_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could not load expenses.'**
  String get couldNotLoadExpenses_neutral;

  /// No description provided for @couldNotLoadExpenses_professional.
  ///
  /// In en, this message translates to:
  /// **'Could not load expenses.'**
  String get couldNotLoadExpenses_professional;

  /// No description provided for @couldNotLoadExpenses_legal.
  ///
  /// In en, this message translates to:
  /// **'Could not load expenses.'**
  String get couldNotLoadExpenses_legal;

  /// No description provided for @noExpensesInThisRange_neutral.
  ///
  /// In en, this message translates to:
  /// **'No expenses in this range. Log expenses from the dashboard.'**
  String get noExpensesInThisRange_neutral;

  /// No description provided for @noExpensesInThisRange_professional.
  ///
  /// In en, this message translates to:
  /// **'No expenses in this range. Log expenses from the dashboard.'**
  String get noExpensesInThisRange_professional;

  /// No description provided for @noExpensesInThisRange_legal.
  ///
  /// In en, this message translates to:
  /// **'No expenses in this range. Log expenses from the dashboard.'**
  String get noExpensesInThisRange_legal;

  /// No description provided for @exportsUseYourLiveCase_neutral.
  ///
  /// In en, this message translates to:
  /// **'Exports use your live case data. Pro may be required for full packets without watermarks.'**
  String get exportsUseYourLiveCase_neutral;

  /// No description provided for @exportsUseYourLiveCase_professional.
  ///
  /// In en, this message translates to:
  /// **'Exports use your live case data. Pro may be required for full packets without watermarks.'**
  String get exportsUseYourLiveCase_professional;

  /// No description provided for @exportsUseYourLiveCase_legal.
  ///
  /// In en, this message translates to:
  /// **'Exports use your live case data. Pro may be required for full packets without watermarks.'**
  String get exportsUseYourLiveCase_legal;

  /// No description provided for @caseSnapshot_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case snapshot'**
  String get caseSnapshot_neutral;

  /// No description provided for @caseSnapshot_professional.
  ///
  /// In en, this message translates to:
  /// **'Case snapshot'**
  String get caseSnapshot_professional;

  /// No description provided for @caseSnapshot_legal.
  ///
  /// In en, this message translates to:
  /// **'Case snapshot'**
  String get caseSnapshot_legal;

  /// No description provided for @totalRange_neutral.
  ///
  /// In en, this message translates to:
  /// **'Total (range)'**
  String get totalRange_neutral;

  /// No description provided for @totalRange_professional.
  ///
  /// In en, this message translates to:
  /// **'Total (range)'**
  String get totalRange_professional;

  /// No description provided for @totalRange_legal.
  ///
  /// In en, this message translates to:
  /// **'Total (range)'**
  String get totalRange_legal;

  /// No description provided for @outstanding_neutral.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstanding_neutral;

  /// No description provided for @outstanding_professional.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstanding_professional;

  /// No description provided for @outstanding_legal.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstanding_legal;

  /// No description provided for @first60Seconds_neutral.
  ///
  /// In en, this message translates to:
  /// **'First 60 seconds'**
  String get first60Seconds_neutral;

  /// No description provided for @first60Seconds_professional.
  ///
  /// In en, this message translates to:
  /// **'First 60 seconds'**
  String get first60Seconds_professional;

  /// No description provided for @first60Seconds_legal.
  ///
  /// In en, this message translates to:
  /// **'First 60 seconds'**
  String get first60Seconds_legal;

  /// No description provided for @useThisQuickCommandCenter_neutral.
  ///
  /// In en, this message translates to:
  /// **'Use this quick command center to understand your setup, your action queue, and your trust status.'**
  String get useThisQuickCommandCenter_neutral;

  /// No description provided for @useThisQuickCommandCenter_professional.
  ///
  /// In en, this message translates to:
  /// **'Use this quick command center to understand your setup, your action queue, and your trust status.'**
  String get useThisQuickCommandCenter_professional;

  /// No description provided for @useThisQuickCommandCenter_legal.
  ///
  /// In en, this message translates to:
  /// **'Use this quick command center to understand your setup, your action queue, and your trust status.'**
  String get useThisQuickCommandCenter_legal;

  /// No description provided for @wereHereToHelp_neutral.
  ///
  /// In en, this message translates to:
  /// **'We’re here to help'**
  String get wereHereToHelp_neutral;

  /// No description provided for @wereHereToHelp_professional.
  ///
  /// In en, this message translates to:
  /// **'We’re here to help'**
  String get wereHereToHelp_professional;

  /// No description provided for @wereHereToHelp_legal.
  ///
  /// In en, this message translates to:
  /// **'We’re here to help'**
  String get wereHereToHelp_legal;

  /// No description provided for @getAnswersContactSupportOr_neutral.
  ///
  /// In en, this message translates to:
  /// **'Get answers, contact support, or start a conversation. '**
  String get getAnswersContactSupportOr_neutral;

  /// No description provided for @getAnswersContactSupportOr_professional.
  ///
  /// In en, this message translates to:
  /// **'Get answers, contact support, or start a conversation. '**
  String get getAnswersContactSupportOr_professional;

  /// No description provided for @getAnswersContactSupportOr_legal.
  ///
  /// In en, this message translates to:
  /// **'Get answers, contact support, or start a conversation. '**
  String get getAnswersContactSupportOr_legal;

  /// No description provided for @faqs_neutral.
  ///
  /// In en, this message translates to:
  /// **'FAQs'**
  String get faqs_neutral;

  /// No description provided for @faqs_professional.
  ///
  /// In en, this message translates to:
  /// **'FAQs'**
  String get faqs_professional;

  /// No description provided for @faqs_legal.
  ///
  /// In en, this message translates to:
  /// **'FAQs'**
  String get faqs_legal;

  /// No description provided for @timelineEntriesAreTimestampedWhen_neutral.
  ///
  /// In en, this message translates to:
  /// **'• Timeline entries are time-stamped when saved.\\n'**
  String get timelineEntriesAreTimestampedWhen_neutral;

  /// No description provided for @timelineEntriesAreTimestampedWhen_professional.
  ///
  /// In en, this message translates to:
  /// **'• Timeline entries are time-stamped when saved.\\n'**
  String get timelineEntriesAreTimestampedWhen_professional;

  /// No description provided for @timelineEntriesAreTimestampedWhen_legal.
  ///
  /// In en, this message translates to:
  /// **'• Timeline entries are time-stamped when saved.\\n'**
  String get timelineEntriesAreTimestampedWhen_legal;

  /// No description provided for @inviteAttorney_neutral.
  ///
  /// In en, this message translates to:
  /// **'Invite attorney'**
  String get inviteAttorney_neutral;

  /// No description provided for @inviteAttorney_professional.
  ///
  /// In en, this message translates to:
  /// **'Invite attorney'**
  String get inviteAttorney_professional;

  /// No description provided for @inviteAttorney_legal.
  ///
  /// In en, this message translates to:
  /// **'Invite attorney'**
  String get inviteAttorney_legal;

  /// No description provided for @counselGetsReadonlyAccessTo_neutral.
  ///
  /// In en, this message translates to:
  /// **'Counsel gets read-only access to this case. Share the invite ID so they can sign in '**
  String get counselGetsReadonlyAccessTo_neutral;

  /// No description provided for @counselGetsReadonlyAccessTo_professional.
  ///
  /// In en, this message translates to:
  /// **'Counsel gets read-only access to this case. Share the invite ID so they can sign in '**
  String get counselGetsReadonlyAccessTo_professional;

  /// No description provided for @counselGetsReadonlyAccessTo_legal.
  ///
  /// In en, this message translates to:
  /// **'Counsel gets read-only access to this case. Share the invite ID so they can sign in '**
  String get counselGetsReadonlyAccessTo_legal;

  /// No description provided for @inviteId_neutral.
  ///
  /// In en, this message translates to:
  /// **'Invite ID'**
  String get inviteId_neutral;

  /// No description provided for @inviteId_professional.
  ///
  /// In en, this message translates to:
  /// **'Invite ID'**
  String get inviteId_professional;

  /// No description provided for @inviteId_legal.
  ///
  /// In en, this message translates to:
  /// **'Invite ID'**
  String get inviteId_legal;

  /// No description provided for @askYourAttorneyToInstall_neutral.
  ///
  /// In en, this message translates to:
  /// **'Ask your attorney to install ParentLedger, create an account, then enter this invite '**
  String get askYourAttorneyToInstall_neutral;

  /// No description provided for @askYourAttorneyToInstall_professional.
  ///
  /// In en, this message translates to:
  /// **'Ask your attorney to install ParentLedger, create an account, then enter this invite '**
  String get askYourAttorneyToInstall_professional;

  /// No description provided for @askYourAttorneyToInstall_legal.
  ///
  /// In en, this message translates to:
  /// **'Ask your attorney to install ParentLedger, create an account, then enter this invite '**
  String get askYourAttorneyToInstall_legal;

  /// No description provided for @nextCreateYourProfileAccept_neutral.
  ///
  /// In en, this message translates to:
  /// **'Next: create your profile, accept terms, add your children, then choose a plan or start with limited access.'**
  String get nextCreateYourProfileAccept_neutral;

  /// No description provided for @nextCreateYourProfileAccept_professional.
  ///
  /// In en, this message translates to:
  /// **'Next: create your profile, accept terms, add your children, then choose a plan or start with limited access.'**
  String get nextCreateYourProfileAccept_professional;

  /// No description provided for @nextCreateYourProfileAccept_legal.
  ///
  /// In en, this message translates to:
  /// **'Next: create your profile, accept terms, add your children, then choose a plan or start with limited access.'**
  String get nextCreateYourProfileAccept_legal;

  /// No description provided for @grantsReadonlyAccessToCase_neutral.
  ///
  /// In en, this message translates to:
  /// **'Grants read-only access to case activity and records'**
  String get grantsReadonlyAccessToCase_neutral;

  /// No description provided for @grantsReadonlyAccessToCase_professional.
  ///
  /// In en, this message translates to:
  /// **'Grants read-only access to case activity and records'**
  String get grantsReadonlyAccessToCase_professional;

  /// No description provided for @grantsReadonlyAccessToCase_legal.
  ///
  /// In en, this message translates to:
  /// **'Grants read-only access to case activity and records'**
  String get grantsReadonlyAccessToCase_legal;

  /// No description provided for @phoneNumber_neutral.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber_neutral;

  /// No description provided for @phoneNumber_professional.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber_professional;

  /// No description provided for @phoneNumber_legal.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber_legal;

  /// No description provided for @courtDocumentSentDeliveryConfirmed_neutral.
  ///
  /// In en, this message translates to:
  /// **'Court document sent — delivery confirmed from ParentLedger.'**
  String get courtDocumentSentDeliveryConfirmed_neutral;

  /// No description provided for @courtDocumentSentDeliveryConfirmed_professional.
  ///
  /// In en, this message translates to:
  /// **'Court document sent — delivery confirmed from ParentLedger.'**
  String get courtDocumentSentDeliveryConfirmed_professional;

  /// No description provided for @courtDocumentSentDeliveryConfirmed_legal.
  ///
  /// In en, this message translates to:
  /// **'Court document sent — delivery confirmed from ParentLedger.'**
  String get courtDocumentSentDeliveryConfirmed_legal;

  /// No description provided for @generatedByParentledger_neutral.
  ///
  /// In en, this message translates to:
  /// **'Generated by ParentLedger'**
  String get generatedByParentledger_neutral;

  /// No description provided for @generatedByParentledger_professional.
  ///
  /// In en, this message translates to:
  /// **'Generated by ParentLedger'**
  String get generatedByParentledger_professional;

  /// No description provided for @generatedByParentledger_legal.
  ///
  /// In en, this message translates to:
  /// **'Generated by ParentLedger'**
  String get generatedByParentledger_legal;

  /// No description provided for @thisDocumentIsACompiled_neutral.
  ///
  /// In en, this message translates to:
  /// **'This document is a compiled record of logged events '**
  String get thisDocumentIsACompiled_neutral;

  /// No description provided for @thisDocumentIsACompiled_professional.
  ///
  /// In en, this message translates to:
  /// **'This document is a compiled record of logged events '**
  String get thisDocumentIsACompiled_professional;

  /// No description provided for @thisDocumentIsACompiled_legal.
  ///
  /// In en, this message translates to:
  /// **'This document is a compiled record of logged events '**
  String get thisDocumentIsACompiled_legal;

  /// No description provided for @counselCopyWatermarked_neutral.
  ///
  /// In en, this message translates to:
  /// **'COUNSEL COPY — WATERMARKED'**
  String get counselCopyWatermarked_neutral;

  /// No description provided for @counselCopyWatermarked_professional.
  ///
  /// In en, this message translates to:
  /// **'COUNSEL COPY — WATERMARKED'**
  String get counselCopyWatermarked_professional;

  /// No description provided for @counselCopyWatermarked_legal.
  ///
  /// In en, this message translates to:
  /// **'COUNSEL COPY — WATERMARKED'**
  String get counselCopyWatermarked_legal;

  /// No description provided for @deliverToCounselOrCourt_neutral.
  ///
  /// In en, this message translates to:
  /// **'Deliver to counsel or court'**
  String get deliverToCounselOrCourt_neutral;

  /// No description provided for @deliverToCounselOrCourt_professional.
  ///
  /// In en, this message translates to:
  /// **'Deliver to counsel or court'**
  String get deliverToCounselOrCourt_professional;

  /// No description provided for @deliverToCounselOrCourt_legal.
  ///
  /// In en, this message translates to:
  /// **'Deliver to counsel or court'**
  String get deliverToCounselOrCourt_legal;

  /// No description provided for @structuredIndex_neutral.
  ///
  /// In en, this message translates to:
  /// **'Structured index'**
  String get structuredIndex_neutral;

  /// No description provided for @structuredIndex_professional.
  ///
  /// In en, this message translates to:
  /// **'Structured index'**
  String get structuredIndex_professional;

  /// No description provided for @structuredIndex_legal.
  ///
  /// In en, this message translates to:
  /// **'Structured index'**
  String get structuredIndex_legal;

  /// No description provided for @thisSummaryIsDerivedFrom_neutral.
  ///
  /// In en, this message translates to:
  /// **'This summary is derived from dated communications in this case. '**
  String get thisSummaryIsDerivedFrom_neutral;

  /// No description provided for @thisSummaryIsDerivedFrom_professional.
  ///
  /// In en, this message translates to:
  /// **'This summary is derived from dated communications in this case. '**
  String get thisSummaryIsDerivedFrom_professional;

  /// No description provided for @thisSummaryIsDerivedFrom_legal.
  ///
  /// In en, this message translates to:
  /// **'This summary is derived from dated communications in this case. '**
  String get thisSummaryIsDerivedFrom_legal;

  /// No description provided for @appName_neutral.
  ///
  /// In en, this message translates to:
  /// **'ParentLedger'**
  String get appName_neutral;

  /// No description provided for @appName_professional.
  ///
  /// In en, this message translates to:
  /// **'ParentLedger'**
  String get appName_professional;

  /// No description provided for @appName_legal.
  ///
  /// In en, this message translates to:
  /// **'ParentLedger'**
  String get appName_legal;

  /// No description provided for @custodyClarityPeace_neutral.
  ///
  /// In en, this message translates to:
  /// **'Custody. Clarity. Peace.'**
  String get custodyClarityPeace_neutral;

  /// No description provided for @custodyClarityPeace_professional.
  ///
  /// In en, this message translates to:
  /// **'Custody. Clarity. Peace.'**
  String get custodyClarityPeace_professional;

  /// No description provided for @custodyClarityPeace_legal.
  ///
  /// In en, this message translates to:
  /// **'Custody. Clarity. Peace.'**
  String get custodyClarityPeace_legal;

  /// No description provided for @changeNumber_neutral.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber_neutral;

  /// No description provided for @changeNumber_professional.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber_professional;

  /// No description provided for @changeNumber_legal.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber_legal;

  /// No description provided for @noCaseLinkedYetComplete2_neutral.
  ///
  /// In en, this message translates to:
  /// **'No case linked yet. Complete workspace setup to use case messages.'**
  String get noCaseLinkedYetComplete2_neutral;

  /// No description provided for @noCaseLinkedYetComplete2_professional.
  ///
  /// In en, this message translates to:
  /// **'No case linked yet. Complete workspace setup to use case messages.'**
  String get noCaseLinkedYetComplete2_professional;

  /// No description provided for @noCaseLinkedYetComplete2_legal.
  ///
  /// In en, this message translates to:
  /// **'No case linked yet. Complete workspace setup to use case messages.'**
  String get noCaseLinkedYetComplete2_legal;

  /// No description provided for @noThreadsFound_neutral.
  ///
  /// In en, this message translates to:
  /// **'No threads found.'**
  String get noThreadsFound_neutral;

  /// No description provided for @noThreadsFound_professional.
  ///
  /// In en, this message translates to:
  /// **'No threads found.'**
  String get noThreadsFound_professional;

  /// No description provided for @noThreadsFound_legal.
  ///
  /// In en, this message translates to:
  /// **'No threads found.'**
  String get noThreadsFound_legal;

  /// No description provided for @setupProgress_neutral.
  ///
  /// In en, this message translates to:
  /// **'Setup progress'**
  String get setupProgress_neutral;

  /// No description provided for @setupProgress_professional.
  ///
  /// In en, this message translates to:
  /// **'Setup progress'**
  String get setupProgress_professional;

  /// No description provided for @setupProgress_legal.
  ///
  /// In en, this message translates to:
  /// **'Setup progress'**
  String get setupProgress_legal;

  /// No description provided for @loadingPlans_neutral.
  ///
  /// In en, this message translates to:
  /// **'Loading plans…'**
  String get loadingPlans_neutral;

  /// No description provided for @loadingPlans_professional.
  ///
  /// In en, this message translates to:
  /// **'Loading plans…'**
  String get loadingPlans_professional;

  /// No description provided for @loadingPlans_legal.
  ///
  /// In en, this message translates to:
  /// **'Loading plans…'**
  String get loadingPlans_legal;

  /// No description provided for @plansUnavailable_neutral.
  ///
  /// In en, this message translates to:
  /// **'Plans unavailable'**
  String get plansUnavailable_neutral;

  /// No description provided for @plansUnavailable_professional.
  ///
  /// In en, this message translates to:
  /// **'Plans unavailable'**
  String get plansUnavailable_professional;

  /// No description provided for @plansUnavailable_legal.
  ///
  /// In en, this message translates to:
  /// **'Plans unavailable'**
  String get plansUnavailable_legal;

  /// No description provided for @weCouldntLoadPlansFrom_neutral.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load plans from the app store. Check your connection and try again — or continue with limited access.'**
  String get weCouldntLoadPlansFrom_neutral;

  /// No description provided for @weCouldntLoadPlansFrom_professional.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load plans from the app store. Check your connection and try again — or continue with limited access.'**
  String get weCouldntLoadPlansFrom_professional;

  /// No description provided for @weCouldntLoadPlansFrom_legal.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load plans from the app store. Check your connection and try again — or continue with limited access.'**
  String get weCouldntLoadPlansFrom_legal;

  /// No description provided for @skipForNow_neutral.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow_neutral;

  /// No description provided for @skipForNow_professional.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow_professional;

  /// No description provided for @skipForNow_legal.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow_legal;

  /// No description provided for @trackEveryExpenseAndKnow_neutral.
  ///
  /// In en, this message translates to:
  /// **'Track every expense and know exactly who owes what.'**
  String get trackEveryExpenseAndKnow_neutral;

  /// No description provided for @trackEveryExpenseAndKnow_professional.
  ///
  /// In en, this message translates to:
  /// **'Track every expense and know exactly who owes what.'**
  String get trackEveryExpenseAndKnow_professional;

  /// No description provided for @trackEveryExpenseAndKnow_legal.
  ///
  /// In en, this message translates to:
  /// **'Track every expense and know exactly who owes what.'**
  String get trackEveryExpenseAndKnow_legal;

  /// No description provided for @finalAmountIsShownIn_neutral.
  ///
  /// In en, this message translates to:
  /// **'Final amount is shown in your app store before you confirm.'**
  String get finalAmountIsShownIn_neutral;

  /// No description provided for @finalAmountIsShownIn_professional.
  ///
  /// In en, this message translates to:
  /// **'Final amount is shown in your app store before you confirm.'**
  String get finalAmountIsShownIn_professional;

  /// No description provided for @finalAmountIsShownIn_legal.
  ///
  /// In en, this message translates to:
  /// **'Final amount is shown in your app store before you confirm.'**
  String get finalAmountIsShownIn_legal;

  /// No description provided for @whyThisWorks_neutral.
  ///
  /// In en, this message translates to:
  /// **'Why this works'**
  String get whyThisWorks_neutral;

  /// No description provided for @whyThisWorks_professional.
  ///
  /// In en, this message translates to:
  /// **'Why this works'**
  String get whyThisWorks_professional;

  /// No description provided for @whyThisWorks_legal.
  ///
  /// In en, this message translates to:
  /// **'Why this works'**
  String get whyThisWorks_legal;

  /// No description provided for @startFreeTrial_neutral.
  ///
  /// In en, this message translates to:
  /// **'Start Free Trial'**
  String get startFreeTrial_neutral;

  /// No description provided for @startFreeTrial_professional.
  ///
  /// In en, this message translates to:
  /// **'Start Free Trial'**
  String get startFreeTrial_professional;

  /// No description provided for @startFreeTrial_legal.
  ///
  /// In en, this message translates to:
  /// **'Start Free Trial'**
  String get startFreeTrial_legal;

  /// No description provided for @noPaymentsHandledInThis_neutral.
  ///
  /// In en, this message translates to:
  /// **'No payments handled in this app. Just clear records and shared visibility.'**
  String get noPaymentsHandledInThis_neutral;

  /// No description provided for @noPaymentsHandledInThis_professional.
  ///
  /// In en, this message translates to:
  /// **'No payments handled in this app. Just clear records and shared visibility.'**
  String get noPaymentsHandledInThis_professional;

  /// No description provided for @noPaymentsHandledInThis_legal.
  ///
  /// In en, this message translates to:
  /// **'No payments handled in this app. Just clear records and shared visibility.'**
  String get noPaymentsHandledInThis_legal;

  /// No description provided for @restorePurchases_neutral.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases_neutral;

  /// No description provided for @restorePurchases_professional.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases_professional;

  /// No description provided for @restorePurchases_legal.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases_legal;

  /// No description provided for @manageSubscription_neutral.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription_neutral;

  /// No description provided for @manageSubscription_professional.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription_professional;

  /// No description provided for @manageSubscription_legal.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscription_legal;

  /// No description provided for @billingIsHandledOnlyBy_neutral.
  ///
  /// In en, this message translates to:
  /// **'Billing is handled only by your app store account. Cancel or change anytime from store settings.'**
  String get billingIsHandledOnlyBy_neutral;

  /// No description provided for @billingIsHandledOnlyBy_professional.
  ///
  /// In en, this message translates to:
  /// **'Billing is handled only by your app store account. Cancel or change anytime from store settings.'**
  String get billingIsHandledOnlyBy_professional;

  /// No description provided for @billingIsHandledOnlyBy_legal.
  ///
  /// In en, this message translates to:
  /// **'Billing is handled only by your app store account. Cancel or change anytime from store settings.'**
  String get billingIsHandledOnlyBy_legal;

  /// No description provided for @noCaseLinkedCompleteSetup2_neutral.
  ///
  /// In en, this message translates to:
  /// **'No case linked. Complete setup to view pending expenses.'**
  String get noCaseLinkedCompleteSetup2_neutral;

  /// No description provided for @noCaseLinkedCompleteSetup2_professional.
  ///
  /// In en, this message translates to:
  /// **'No case linked. Complete setup to view pending expenses.'**
  String get noCaseLinkedCompleteSetup2_professional;

  /// No description provided for @noCaseLinkedCompleteSetup2_legal.
  ///
  /// In en, this message translates to:
  /// **'No case linked. Complete setup to view pending expenses.'**
  String get noCaseLinkedCompleteSetup2_legal;

  /// No description provided for @pendingExpenses_neutral.
  ///
  /// In en, this message translates to:
  /// **'Pending expenses'**
  String get pendingExpenses_neutral;

  /// No description provided for @pendingExpenses_professional.
  ///
  /// In en, this message translates to:
  /// **'Pending expenses'**
  String get pendingExpenses_professional;

  /// No description provided for @pendingExpenses_legal.
  ///
  /// In en, this message translates to:
  /// **'Pending expenses'**
  String get pendingExpenses_legal;

  /// No description provided for @allRecordedExpensesAreMarked_neutral.
  ///
  /// In en, this message translates to:
  /// **'All recorded expenses are marked paid, or none have been added yet.'**
  String get allRecordedExpensesAreMarked_neutral;

  /// No description provided for @allRecordedExpensesAreMarked_professional.
  ///
  /// In en, this message translates to:
  /// **'All recorded expenses are marked paid, or none have been added yet.'**
  String get allRecordedExpensesAreMarked_professional;

  /// No description provided for @allRecordedExpensesAreMarked_legal.
  ///
  /// In en, this message translates to:
  /// **'All recorded expenses are marked paid, or none have been added yet.'**
  String get allRecordedExpensesAreMarked_legal;

  /// No description provided for @inviteSent_neutral.
  ///
  /// In en, this message translates to:
  /// **'Invite sent'**
  String get inviteSent_neutral;

  /// No description provided for @inviteSent_professional.
  ///
  /// In en, this message translates to:
  /// **'Invite sent'**
  String get inviteSent_professional;

  /// No description provided for @inviteSent_legal.
  ///
  /// In en, this message translates to:
  /// **'Invite sent'**
  String get inviteSent_legal;

  /// No description provided for @tapToResendOrCancel_neutral.
  ///
  /// In en, this message translates to:
  /// **'Tap to resend or cancel'**
  String get tapToResendOrCancel_neutral;

  /// No description provided for @tapToResendOrCancel_professional.
  ///
  /// In en, this message translates to:
  /// **'Tap to resend or cancel'**
  String get tapToResendOrCancel_professional;

  /// No description provided for @tapToResendOrCancel_legal.
  ///
  /// In en, this message translates to:
  /// **'Tap to resend or cancel'**
  String get tapToResendOrCancel_legal;

  /// No description provided for @currentPlan_neutral.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get currentPlan_neutral;

  /// No description provided for @currentPlan_professional.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get currentPlan_professional;

  /// No description provided for @currentPlan_legal.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get currentPlan_legal;

  /// No description provided for @noCaseIsLinkedTo2_neutral.
  ///
  /// In en, this message translates to:
  /// **'No case is linked to your profile yet. Complete setup to view the legal timeline.'**
  String get noCaseIsLinkedTo2_neutral;

  /// No description provided for @noCaseIsLinkedTo2_professional.
  ///
  /// In en, this message translates to:
  /// **'No case is linked to your profile yet. Complete setup to view the legal timeline.'**
  String get noCaseIsLinkedTo2_professional;

  /// No description provided for @noCaseIsLinkedTo2_legal.
  ///
  /// In en, this message translates to:
  /// **'No case is linked to your profile yet. Complete setup to view the legal timeline.'**
  String get noCaseIsLinkedTo2_legal;

  /// No description provided for @createAccount_neutral.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount_neutral;

  /// No description provided for @createAccount_professional.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount_professional;

  /// No description provided for @createAccount_legal.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount_legal;

  /// No description provided for @selectRole_neutral.
  ///
  /// In en, this message translates to:
  /// **'Select role'**
  String get selectRole_neutral;

  /// No description provided for @selectRole_professional.
  ///
  /// In en, this message translates to:
  /// **'Select role'**
  String get selectRole_professional;

  /// No description provided for @selectRole_legal.
  ///
  /// In en, this message translates to:
  /// **'Select role'**
  String get selectRole_legal;

  /// No description provided for @createAClearCourtreadyExpense_neutral.
  ///
  /// In en, this message translates to:
  /// **'Create a clear, court-ready expense record.'**
  String get createAClearCourtreadyExpense_neutral;

  /// No description provided for @createAClearCourtreadyExpense_professional.
  ///
  /// In en, this message translates to:
  /// **'Create a clear, court-ready expense record.'**
  String get createAClearCourtreadyExpense_professional;

  /// No description provided for @createAClearCourtreadyExpense_legal.
  ///
  /// In en, this message translates to:
  /// **'Create a clear, court-ready expense record.'**
  String get createAClearCourtreadyExpense_legal;

  /// No description provided for @iAgreeToTheTerms_neutral.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms & Privacy Policy'**
  String get iAgreeToTheTerms_neutral;

  /// No description provided for @iAgreeToTheTerms_professional.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms & Privacy Policy'**
  String get iAgreeToTheTerms_professional;

  /// No description provided for @iAgreeToTheTerms_legal.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms & Privacy Policy'**
  String get iAgreeToTheTerms_legal;

  /// No description provided for @parentledgerIsADocumentationPlatform_neutral.
  ///
  /// In en, this message translates to:
  /// **'ParentLedger is a documentation platform and does not provide legal advice.'**
  String get parentledgerIsADocumentationPlatform_neutral;

  /// No description provided for @parentledgerIsADocumentationPlatform_professional.
  ///
  /// In en, this message translates to:
  /// **'ParentLedger is a documentation platform and does not provide legal advice.'**
  String get parentledgerIsADocumentationPlatform_professional;

  /// No description provided for @parentledgerIsADocumentationPlatform_legal.
  ///
  /// In en, this message translates to:
  /// **'ParentLedger is a documentation platform and does not provide legal advice.'**
  String get parentledgerIsADocumentationPlatform_legal;

  /// No description provided for @somethingWentWrong_neutral.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong_neutral;

  /// No description provided for @somethingWentWrong_professional.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong_professional;

  /// No description provided for @somethingWentWrong_legal.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong_legal;

  /// No description provided for @noUpcomingExchanges_neutral.
  ///
  /// In en, this message translates to:
  /// **'No upcoming exchanges'**
  String get noUpcomingExchanges_neutral;

  /// No description provided for @noUpcomingExchanges_professional.
  ///
  /// In en, this message translates to:
  /// **'No upcoming exchanges'**
  String get noUpcomingExchanges_professional;

  /// No description provided for @noUpcomingExchanges_legal.
  ///
  /// In en, this message translates to:
  /// **'No upcoming exchanges'**
  String get noUpcomingExchanges_legal;

  /// No description provided for @stayOrganizedBySchedulingYour_neutral.
  ///
  /// In en, this message translates to:
  /// **'Stay organized by scheduling your next exchange'**
  String get stayOrganizedBySchedulingYour_neutral;

  /// No description provided for @stayOrganizedBySchedulingYour_professional.
  ///
  /// In en, this message translates to:
  /// **'Stay organized by scheduling your next exchange'**
  String get stayOrganizedBySchedulingYour_professional;

  /// No description provided for @stayOrganizedBySchedulingYour_legal.
  ///
  /// In en, this message translates to:
  /// **'Stay organized by scheduling your next exchange'**
  String get stayOrganizedBySchedulingYour_legal;

  /// No description provided for @allExchangesAreTimestampedAnd_neutral.
  ///
  /// In en, this message translates to:
  /// **'All exchanges are time-stamped and recorded for your case file'**
  String get allExchangesAreTimestampedAnd_neutral;

  /// No description provided for @allExchangesAreTimestampedAnd_professional.
  ///
  /// In en, this message translates to:
  /// **'All exchanges are time-stamped and recorded for your case file'**
  String get allExchangesAreTimestampedAnd_professional;

  /// No description provided for @allExchangesAreTimestampedAnd_legal.
  ///
  /// In en, this message translates to:
  /// **'All exchanges are time-stamped and recorded for your case file'**
  String get allExchangesAreTimestampedAnd_legal;

  /// No description provided for @allUpcoming_neutral.
  ///
  /// In en, this message translates to:
  /// **'All upcoming'**
  String get allUpcoming_neutral;

  /// No description provided for @allUpcoming_professional.
  ///
  /// In en, this message translates to:
  /// **'All upcoming'**
  String get allUpcoming_professional;

  /// No description provided for @allUpcoming_legal.
  ///
  /// In en, this message translates to:
  /// **'All upcoming'**
  String get allUpcoming_legal;

  /// No description provided for @nextExchange_neutral.
  ///
  /// In en, this message translates to:
  /// **'Next exchange'**
  String get nextExchange_neutral;

  /// No description provided for @nextExchange_professional.
  ///
  /// In en, this message translates to:
  /// **'Next exchange'**
  String get nextExchange_professional;

  /// No description provided for @nextExchange_legal.
  ///
  /// In en, this message translates to:
  /// **'Next exchange'**
  String get nextExchange_legal;

  /// No description provided for @sendCourtDocument_neutral.
  ///
  /// In en, this message translates to:
  /// **'Send court document'**
  String get sendCourtDocument_neutral;

  /// No description provided for @sendCourtDocument_professional.
  ///
  /// In en, this message translates to:
  /// **'Send court document'**
  String get sendCourtDocument_professional;

  /// No description provided for @sendCourtDocument_legal.
  ///
  /// In en, this message translates to:
  /// **'Send court document'**
  String get sendCourtDocument_legal;

  /// No description provided for @deliveredFromParentledgerYourMail_neutral.
  ///
  /// In en, this message translates to:
  /// **'Delivered from ParentLedger — your mail app stays closed.'**
  String get deliveredFromParentledgerYourMail_neutral;

  /// No description provided for @deliveredFromParentledgerYourMail_professional.
  ///
  /// In en, this message translates to:
  /// **'Delivered from ParentLedger — your mail app stays closed.'**
  String get deliveredFromParentledgerYourMail_professional;

  /// No description provided for @deliveredFromParentledgerYourMail_legal.
  ///
  /// In en, this message translates to:
  /// **'Delivered from ParentLedger — your mail app stays closed.'**
  String get deliveredFromParentledgerYourMail_legal;

  /// No description provided for @recipientWillReceiveANotice_neutral.
  ///
  /// In en, this message translates to:
  /// **'Recipient will receive a notice that your court packet is ready, with the full document text.'**
  String get recipientWillReceiveANotice_neutral;

  /// No description provided for @recipientWillReceiveANotice_professional.
  ///
  /// In en, this message translates to:
  /// **'Recipient will receive a notice that your court packet is ready, with the full document text.'**
  String get recipientWillReceiveANotice_professional;

  /// No description provided for @recipientWillReceiveANotice_legal.
  ///
  /// In en, this message translates to:
  /// **'Recipient will receive a notice that your court packet is ready, with the full document text.'**
  String get recipientWillReceiveANotice_legal;

  /// No description provided for @sendSecurely_neutral.
  ///
  /// In en, this message translates to:
  /// **'Send securely'**
  String get sendSecurely_neutral;

  /// No description provided for @sendSecurely_professional.
  ///
  /// In en, this message translates to:
  /// **'Send securely'**
  String get sendSecurely_professional;

  /// No description provided for @sendSecurely_legal.
  ///
  /// In en, this message translates to:
  /// **'Send securely'**
  String get sendSecurely_legal;

  /// No description provided for @cancel_neutral.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel_neutral;

  /// No description provided for @cancel_professional.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel_professional;

  /// No description provided for @cancel_legal.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel_legal;

  /// No description provided for @continueYourSubscriptionToKeep_neutral.
  ///
  /// In en, this message translates to:
  /// **'Continue your subscription to keep access to your records and tracking.'**
  String get continueYourSubscriptionToKeep_neutral;

  /// No description provided for @continueYourSubscriptionToKeep_professional.
  ///
  /// In en, this message translates to:
  /// **'Continue your subscription to keep access to your records and tracking.'**
  String get continueYourSubscriptionToKeep_professional;

  /// No description provided for @continueYourSubscriptionToKeep_legal.
  ///
  /// In en, this message translates to:
  /// **'Continue your subscription to keep access to your records and tracking.'**
  String get continueYourSubscriptionToKeep_legal;

  /// No description provided for @skipForNow2_neutral.
  ///
  /// In en, this message translates to:
  /// **'Skip for now?'**
  String get skipForNow2_neutral;

  /// No description provided for @skipForNow2_professional.
  ///
  /// In en, this message translates to:
  /// **'Skip for now?'**
  String get skipForNow2_professional;

  /// No description provided for @skipForNow2_legal.
  ///
  /// In en, this message translates to:
  /// **'Skip for now?'**
  String get skipForNow2_legal;

  /// No description provided for @youCanInviteYourCoparent_neutral.
  ///
  /// In en, this message translates to:
  /// **'You can invite your co-parent anytime from Profile → Invite Co-Parent.'**
  String get youCanInviteYourCoparent_neutral;

  /// No description provided for @youCanInviteYourCoparent_professional.
  ///
  /// In en, this message translates to:
  /// **'You can invite your co-parent anytime from Profile → Invite Co-Parent.'**
  String get youCanInviteYourCoparent_professional;

  /// No description provided for @youCanInviteYourCoparent_legal.
  ///
  /// In en, this message translates to:
  /// **'You can invite your co-parent anytime from Profile → Invite Co-Parent.'**
  String get youCanInviteYourCoparent_legal;

  /// No description provided for @youCanInviteLaterFrom_neutral.
  ///
  /// In en, this message translates to:
  /// **'You can invite later from Profile → Invite Co-Parent.'**
  String get youCanInviteLaterFrom_neutral;

  /// No description provided for @youCanInviteLaterFrom_professional.
  ///
  /// In en, this message translates to:
  /// **'You can invite later from Profile → Invite Co-Parent.'**
  String get youCanInviteLaterFrom_professional;

  /// No description provided for @youCanInviteLaterFrom_legal.
  ///
  /// In en, this message translates to:
  /// **'You can invite later from Profile → Invite Co-Parent.'**
  String get youCanInviteLaterFrom_legal;

  /// No description provided for @connectCoparent_neutral.
  ///
  /// In en, this message translates to:
  /// **'Connect co-parent'**
  String get connectCoparent_neutral;

  /// No description provided for @connectCoparent_professional.
  ///
  /// In en, this message translates to:
  /// **'Connect co-parent'**
  String get connectCoparent_professional;

  /// No description provided for @connectCoparent_legal.
  ///
  /// In en, this message translates to:
  /// **'Connect co-parent'**
  String get connectCoparent_legal;

  /// No description provided for @youCanInviteYourCoparent2_neutral.
  ///
  /// In en, this message translates to:
  /// **'You can invite your co-parent now or later from Profile → Invite Co-Parent.'**
  String get youCanInviteYourCoparent2_neutral;

  /// No description provided for @youCanInviteYourCoparent2_professional.
  ///
  /// In en, this message translates to:
  /// **'You can invite your co-parent now or later from Profile → Invite Co-Parent.'**
  String get youCanInviteYourCoparent2_professional;

  /// No description provided for @youCanInviteYourCoparent2_legal.
  ///
  /// In en, this message translates to:
  /// **'You can invite your co-parent now or later from Profile → Invite Co-Parent.'**
  String get youCanInviteYourCoparent2_legal;

  /// No description provided for @phoneIsRequiredForSecure_neutral.
  ///
  /// In en, this message translates to:
  /// **'Phone is required for secure invite acceptance. We never send a message without your confirmation.'**
  String get phoneIsRequiredForSecure_neutral;

  /// No description provided for @phoneIsRequiredForSecure_professional.
  ///
  /// In en, this message translates to:
  /// **'Phone is required for secure invite acceptance. We never send a message without your confirmation.'**
  String get phoneIsRequiredForSecure_professional;

  /// No description provided for @phoneIsRequiredForSecure_legal.
  ///
  /// In en, this message translates to:
  /// **'Phone is required for secure invite acceptance. We never send a message without your confirmation.'**
  String get phoneIsRequiredForSecure_legal;

  /// No description provided for @sendInvite_neutral.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get sendInvite_neutral;

  /// No description provided for @sendInvite_professional.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get sendInvite_professional;

  /// No description provided for @sendInvite_legal.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get sendInvite_legal;

  /// No description provided for @startupFailureBody_neutral.
  ///
  /// In en, this message translates to:
  /// **'Firebase failed to initialize on this build. Please verify Android Firebase config and restart the app.'**
  String get startupFailureBody_neutral;

  /// No description provided for @startupFailureBody_professional.
  ///
  /// In en, this message translates to:
  /// **'Firebase failed to initialize on this build. Please verify Android Firebase config and restart the app.'**
  String get startupFailureBody_professional;

  /// No description provided for @startupFailureBody_legal.
  ///
  /// In en, this message translates to:
  /// **'Firebase failed to initialize on this build. Please verify Android Firebase config and restart the app.'**
  String get startupFailureBody_legal;

  /// No description provided for @dashboardCaseSubtitle_neutral.
  ///
  /// In en, this message translates to:
  /// **'Here\'s your case at a glance'**
  String get dashboardCaseSubtitle_neutral;

  /// No description provided for @dashboardCaseSubtitle_professional.
  ///
  /// In en, this message translates to:
  /// **'Here\'s your case at a glance'**
  String get dashboardCaseSubtitle_professional;

  /// No description provided for @dashboardCaseSubtitle_legal.
  ///
  /// In en, this message translates to:
  /// **'Here\'s your case at a glance'**
  String get dashboardCaseSubtitle_legal;

  /// No description provided for @dashboardPremiumHeadline_neutral.
  ///
  /// In en, this message translates to:
  /// **'Everything documented. No more arguments.'**
  String get dashboardPremiumHeadline_neutral;

  /// No description provided for @dashboardPremiumHeadline_professional.
  ///
  /// In en, this message translates to:
  /// **'Everything documented. No more arguments.'**
  String get dashboardPremiumHeadline_professional;

  /// No description provided for @dashboardPremiumHeadline_legal.
  ///
  /// In en, this message translates to:
  /// **'Everything documented. No more arguments.'**
  String get dashboardPremiumHeadline_legal;

  /// No description provided for @dashboardPremiumTagline_neutral.
  ///
  /// In en, this message translates to:
  /// **'Track expenses, messages, and custody schedules in one place.'**
  String get dashboardPremiumTagline_neutral;

  /// No description provided for @dashboardPremiumTagline_professional.
  ///
  /// In en, this message translates to:
  /// **'Track expenses, messages, and custody schedules in one place.'**
  String get dashboardPremiumTagline_professional;

  /// No description provided for @dashboardPremiumTagline_legal.
  ///
  /// In en, this message translates to:
  /// **'Track expenses, messages, and custody schedules in one place.'**
  String get dashboardPremiumTagline_legal;

  /// No description provided for @messagesCardTitle_neutral.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesCardTitle_neutral;

  /// No description provided for @messagesCardTitle_professional.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesCardTitle_professional;

  /// No description provided for @messagesCardTitle_legal.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesCardTitle_legal;

  /// No description provided for @messagesPreviewLoading_neutral.
  ///
  /// In en, this message translates to:
  /// **'Loading recent messages…'**
  String get messagesPreviewLoading_neutral;

  /// No description provided for @messagesPreviewLoading_professional.
  ///
  /// In en, this message translates to:
  /// **'Loading recent messages…'**
  String get messagesPreviewLoading_professional;

  /// No description provided for @messagesPreviewLoading_legal.
  ///
  /// In en, this message translates to:
  /// **'Loading recent messages…'**
  String get messagesPreviewLoading_legal;

  /// No description provided for @messagesPreviewEmpty_neutral.
  ///
  /// In en, this message translates to:
  /// **'No recent messages'**
  String get messagesPreviewEmpty_neutral;

  /// No description provided for @messagesPreviewEmpty_professional.
  ///
  /// In en, this message translates to:
  /// **'No recent messages'**
  String get messagesPreviewEmpty_professional;

  /// No description provided for @messagesPreviewEmpty_legal.
  ///
  /// In en, this message translates to:
  /// **'No recent messages'**
  String get messagesPreviewEmpty_legal;

  /// No description provided for @messagesUnreadNone_neutral.
  ///
  /// In en, this message translates to:
  /// **'No unread messages'**
  String get messagesUnreadNone_neutral;

  /// No description provided for @messagesUnreadNone_professional.
  ///
  /// In en, this message translates to:
  /// **'No unread messages'**
  String get messagesUnreadNone_professional;

  /// No description provided for @messagesUnreadNone_legal.
  ///
  /// In en, this message translates to:
  /// **'No unread messages'**
  String get messagesUnreadNone_legal;

  /// No description provided for @messagesUnreadOne_neutral.
  ///
  /// In en, this message translates to:
  /// **'1 unread message'**
  String get messagesUnreadOne_neutral;

  /// No description provided for @messagesUnreadOne_professional.
  ///
  /// In en, this message translates to:
  /// **'1 unread message'**
  String get messagesUnreadOne_professional;

  /// No description provided for @messagesUnreadOne_legal.
  ///
  /// In en, this message translates to:
  /// **'1 unread message'**
  String get messagesUnreadOne_legal;

  /// No description provided for @messagesUnreadMany_neutral.
  ///
  /// In en, this message translates to:
  /// **'{count} unread messages'**
  String messagesUnreadMany_neutral(int count);

  /// No description provided for @messagesUnreadMany_professional.
  ///
  /// In en, this message translates to:
  /// **'{count} unread messages'**
  String messagesUnreadMany_professional(int count);

  /// No description provided for @messagesUnreadMany_legal.
  ///
  /// In en, this message translates to:
  /// **'{count} unread messages'**
  String messagesUnreadMany_legal(int count);

  /// No description provided for @balanceCardSecurePill_neutral.
  ///
  /// In en, this message translates to:
  /// **'All activity is securely documented'**
  String get balanceCardSecurePill_neutral;

  /// No description provided for @balanceCardSecurePill_professional.
  ///
  /// In en, this message translates to:
  /// **'All activity is securely documented'**
  String get balanceCardSecurePill_professional;

  /// No description provided for @balanceCardSecurePill_legal.
  ///
  /// In en, this message translates to:
  /// **'All activity is securely documented'**
  String get balanceCardSecurePill_legal;

  /// No description provided for @dashboardTrustBannerPrimary_neutral.
  ///
  /// In en, this message translates to:
  /// **'Every expense and message is recorded.'**
  String get dashboardTrustBannerPrimary_neutral;

  /// No description provided for @dashboardTrustBannerPrimary_professional.
  ///
  /// In en, this message translates to:
  /// **'Every expense and message is recorded.'**
  String get dashboardTrustBannerPrimary_professional;

  /// No description provided for @dashboardTrustBannerPrimary_legal.
  ///
  /// In en, this message translates to:
  /// **'Every expense and message is recorded.'**
  String get dashboardTrustBannerPrimary_legal;

  /// No description provided for @dashboardTrustBannerSecondary_neutral.
  ///
  /// In en, this message translates to:
  /// **'Export records anytime for court or mediation.'**
  String get dashboardTrustBannerSecondary_neutral;

  /// No description provided for @dashboardTrustBannerSecondary_professional.
  ///
  /// In en, this message translates to:
  /// **'Export records anytime for court or mediation.'**
  String get dashboardTrustBannerSecondary_professional;

  /// No description provided for @dashboardTrustBannerSecondary_legal.
  ///
  /// In en, this message translates to:
  /// **'Export records anytime for court or mediation.'**
  String get dashboardTrustBannerSecondary_legal;

  /// No description provided for @addExpense_neutral.
  ///
  /// In en, this message translates to:
  /// **'+ Add Expense'**
  String get addExpense_neutral;

  /// No description provided for @addExpense_professional.
  ///
  /// In en, this message translates to:
  /// **'Record expense'**
  String get addExpense_professional;

  /// No description provided for @addExpense_legal.
  ///
  /// In en, this message translates to:
  /// **'Document expense'**
  String get addExpense_legal;

  /// No description provided for @addFirstExpense_neutral.
  ///
  /// In en, this message translates to:
  /// **'Add First Expense'**
  String get addFirstExpense_neutral;

  /// No description provided for @addFirstExpense_professional.
  ///
  /// In en, this message translates to:
  /// **'Add first expense record'**
  String get addFirstExpense_professional;

  /// No description provided for @addFirstExpense_legal.
  ///
  /// In en, this message translates to:
  /// **'Create initial expense entry'**
  String get addFirstExpense_legal;

  /// No description provided for @requestReimbursement_neutral.
  ///
  /// In en, this message translates to:
  /// **'Request reimbursement'**
  String get requestReimbursement_neutral;

  /// No description provided for @requestReimbursement_professional.
  ///
  /// In en, this message translates to:
  /// **'Request reimbursement'**
  String get requestReimbursement_professional;

  /// No description provided for @requestReimbursement_legal.
  ///
  /// In en, this message translates to:
  /// **'Request reimbursement'**
  String get requestReimbursement_legal;

  /// No description provided for @requestPayment_neutral.
  ///
  /// In en, this message translates to:
  /// **'Request Payment'**
  String get requestPayment_neutral;

  /// No description provided for @requestPayment_professional.
  ///
  /// In en, this message translates to:
  /// **'Request Payment'**
  String get requestPayment_professional;

  /// No description provided for @requestPayment_legal.
  ///
  /// In en, this message translates to:
  /// **'Request Payment'**
  String get requestPayment_legal;

  /// No description provided for @noMessages_neutral.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessages_neutral;

  /// No description provided for @noMessages_professional.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessages_professional;

  /// No description provided for @noMessages_legal.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessages_legal;

  /// No description provided for @yearly_neutral.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly_neutral;

  /// No description provided for @yearly_professional.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly_professional;

  /// No description provided for @yearly_legal.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly_legal;

  /// No description provided for @monthly_neutral.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly_neutral;

  /// No description provided for @monthly_professional.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly_professional;

  /// No description provided for @monthly_legal.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly_legal;

  /// No description provided for @legalRecordActive_neutral.
  ///
  /// In en, this message translates to:
  /// **'Legal Record: Active'**
  String get legalRecordActive_neutral;

  /// No description provided for @legalRecordActive_professional.
  ///
  /// In en, this message translates to:
  /// **'Legal Record: Active'**
  String get legalRecordActive_professional;

  /// No description provided for @legalRecordActive_legal.
  ///
  /// In en, this message translates to:
  /// **'Legal Record: Active'**
  String get legalRecordActive_legal;

  /// No description provided for @legalRecordReviewRecommended_neutral.
  ///
  /// In en, this message translates to:
  /// **'Legal Record: Review recommended'**
  String get legalRecordReviewRecommended_neutral;

  /// No description provided for @legalRecordReviewRecommended_professional.
  ///
  /// In en, this message translates to:
  /// **'Legal Record: Review recommended'**
  String get legalRecordReviewRecommended_professional;

  /// No description provided for @legalRecordReviewRecommended_legal.
  ///
  /// In en, this message translates to:
  /// **'Legal Record: Review recommended'**
  String get legalRecordReviewRecommended_legal;

  /// No description provided for @insightsUnavailable_neutral.
  ///
  /// In en, this message translates to:
  /// **'Insights unavailable. Try again.'**
  String get insightsUnavailable_neutral;

  /// No description provided for @insightsUnavailable_professional.
  ///
  /// In en, this message translates to:
  /// **'Insights unavailable. Try again.'**
  String get insightsUnavailable_professional;

  /// No description provided for @insightsUnavailable_legal.
  ///
  /// In en, this message translates to:
  /// **'Insights unavailable. Try again.'**
  String get insightsUnavailable_legal;

  /// No description provided for @insightsNoDataYet_neutral.
  ///
  /// In en, this message translates to:
  /// **'No insights available yet.'**
  String get insightsNoDataYet_neutral;

  /// No description provided for @insightsNoDataYet_professional.
  ///
  /// In en, this message translates to:
  /// **'No insights available yet.'**
  String get insightsNoDataYet_professional;

  /// No description provided for @insightsNoDataYet_legal.
  ///
  /// In en, this message translates to:
  /// **'No insights available yet.'**
  String get insightsNoDataYet_legal;

  /// No description provided for @insightsGenerating_neutral.
  ///
  /// In en, this message translates to:
  /// **'Insights are being generated'**
  String get insightsGenerating_neutral;

  /// No description provided for @insightsGenerating_professional.
  ///
  /// In en, this message translates to:
  /// **'Insights are being generated'**
  String get insightsGenerating_professional;

  /// No description provided for @insightsGenerating_legal.
  ///
  /// In en, this message translates to:
  /// **'Insights are being generated'**
  String get insightsGenerating_legal;

  /// No description provided for @backToSignIn_neutral.
  ///
  /// In en, this message translates to:
  /// **'Back To Sign In'**
  String get backToSignIn_neutral;

  /// No description provided for @backToSignIn_professional.
  ///
  /// In en, this message translates to:
  /// **'Back To Sign In'**
  String get backToSignIn_professional;

  /// No description provided for @backToSignIn_legal.
  ///
  /// In en, this message translates to:
  /// **'Back To Sign In'**
  String get backToSignIn_legal;

  /// No description provided for @actionInbox_neutral.
  ///
  /// In en, this message translates to:
  /// **'Action Inbox'**
  String get actionInbox_neutral;

  /// No description provided for @actionInbox_professional.
  ///
  /// In en, this message translates to:
  /// **'Action Inbox'**
  String get actionInbox_professional;

  /// No description provided for @actionInbox_legal.
  ///
  /// In en, this message translates to:
  /// **'Action Inbox'**
  String get actionInbox_legal;

  /// No description provided for @aiFairnessAnalysis_neutral.
  ///
  /// In en, this message translates to:
  /// **'Ai Fairness Analysis'**
  String get aiFairnessAnalysis_neutral;

  /// No description provided for @aiFairnessAnalysis_professional.
  ///
  /// In en, this message translates to:
  /// **'Ai Fairness Analysis'**
  String get aiFairnessAnalysis_professional;

  /// No description provided for @aiFairnessAnalysis_legal.
  ///
  /// In en, this message translates to:
  /// **'Ai Fairness Analysis'**
  String get aiFairnessAnalysis_legal;

  /// No description provided for @counterSuggestionFlowOpensFrom_neutral.
  ///
  /// In en, this message translates to:
  /// **'Counter Suggestion Flow Opens From'**
  String get counterSuggestionFlowOpensFrom_neutral;

  /// No description provided for @counterSuggestionFlowOpensFrom_professional.
  ///
  /// In en, this message translates to:
  /// **'Counter Suggestion Flow Opens From'**
  String get counterSuggestionFlowOpensFrom_professional;

  /// No description provided for @counterSuggestionFlowOpensFrom_legal.
  ///
  /// In en, this message translates to:
  /// **'Counter Suggestion Flow Opens From'**
  String get counterSuggestionFlowOpensFrom_legal;

  /// No description provided for @counterSuggestion_neutral.
  ///
  /// In en, this message translates to:
  /// **'Counter Suggestion'**
  String get counterSuggestion_neutral;

  /// No description provided for @counterSuggestion_professional.
  ///
  /// In en, this message translates to:
  /// **'Counter Suggestion'**
  String get counterSuggestion_professional;

  /// No description provided for @counterSuggestion_legal.
  ///
  /// In en, this message translates to:
  /// **'Counter Suggestion'**
  String get counterSuggestion_legal;

  /// No description provided for @aiCompromiseSavedToReview_neutral.
  ///
  /// In en, this message translates to:
  /// **'Ai Compromise Saved To Review'**
  String get aiCompromiseSavedToReview_neutral;

  /// No description provided for @aiCompromiseSavedToReview_professional.
  ///
  /// In en, this message translates to:
  /// **'Ai Compromise Saved To Review'**
  String get aiCompromiseSavedToReview_professional;

  /// No description provided for @aiCompromiseSavedToReview_legal.
  ///
  /// In en, this message translates to:
  /// **'Ai Compromise Saved To Review'**
  String get aiCompromiseSavedToReview_legal;

  /// No description provided for @acceptAiProposal_neutral.
  ///
  /// In en, this message translates to:
  /// **'Accept Ai Proposal'**
  String get acceptAiProposal_neutral;

  /// No description provided for @acceptAiProposal_professional.
  ///
  /// In en, this message translates to:
  /// **'Accept Ai Proposal'**
  String get acceptAiProposal_professional;

  /// No description provided for @acceptAiProposal_legal.
  ///
  /// In en, this message translates to:
  /// **'Accept Ai Proposal'**
  String get acceptAiProposal_legal;

  /// No description provided for @aiComplianceScan_neutral.
  ///
  /// In en, this message translates to:
  /// **'Ai Compliance Scan'**
  String get aiComplianceScan_neutral;

  /// No description provided for @aiComplianceScan_professional.
  ///
  /// In en, this message translates to:
  /// **'Ai Compliance Scan'**
  String get aiComplianceScan_professional;

  /// No description provided for @aiComplianceScan_legal.
  ///
  /// In en, this message translates to:
  /// **'Ai Compliance Scan'**
  String get aiComplianceScan_legal;

  /// No description provided for @tryAgain_neutral.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain_neutral;

  /// No description provided for @tryAgain_professional.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain_professional;

  /// No description provided for @tryAgain_legal.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain_legal;

  /// No description provided for @reviewExpense_neutral.
  ///
  /// In en, this message translates to:
  /// **'Review Expense'**
  String get reviewExpense_neutral;

  /// No description provided for @reviewExpense_professional.
  ///
  /// In en, this message translates to:
  /// **'Review Expense'**
  String get reviewExpense_professional;

  /// No description provided for @reviewExpense_legal.
  ///
  /// In en, this message translates to:
  /// **'Review Expense'**
  String get reviewExpense_legal;

  /// No description provided for @noActiveCaseFound_neutral.
  ///
  /// In en, this message translates to:
  /// **'No Active Case Found'**
  String get noActiveCaseFound_neutral;

  /// No description provided for @noActiveCaseFound_professional.
  ///
  /// In en, this message translates to:
  /// **'No Active Case Found'**
  String get noActiveCaseFound_professional;

  /// No description provided for @noActiveCaseFound_legal.
  ///
  /// In en, this message translates to:
  /// **'No Active Case Found'**
  String get noActiveCaseFound_legal;

  /// No description provided for @expenseNotFound_neutral.
  ///
  /// In en, this message translates to:
  /// **'Expense Not Found'**
  String get expenseNotFound_neutral;

  /// No description provided for @expenseNotFound_professional.
  ///
  /// In en, this message translates to:
  /// **'Expense Not Found'**
  String get expenseNotFound_professional;

  /// No description provided for @expenseNotFound_legal.
  ///
  /// In en, this message translates to:
  /// **'Expense Not Found'**
  String get expenseNotFound_legal;

  /// No description provided for @approveExpense_neutral.
  ///
  /// In en, this message translates to:
  /// **'Approve Expense'**
  String get approveExpense_neutral;

  /// No description provided for @approveExpense_professional.
  ///
  /// In en, this message translates to:
  /// **'Approve Expense'**
  String get approveExpense_professional;

  /// No description provided for @approveExpense_legal.
  ///
  /// In en, this message translates to:
  /// **'Approve Expense'**
  String get approveExpense_legal;

  /// No description provided for @denyExpense_neutral.
  ///
  /// In en, this message translates to:
  /// **'Deny Expense'**
  String get denyExpense_neutral;

  /// No description provided for @denyExpense_professional.
  ///
  /// In en, this message translates to:
  /// **'Deny Expense'**
  String get denyExpense_professional;

  /// No description provided for @denyExpense_legal.
  ///
  /// In en, this message translates to:
  /// **'Deny Expense'**
  String get denyExpense_legal;

  /// No description provided for @counselAccess_neutral.
  ///
  /// In en, this message translates to:
  /// **'Counsel Access'**
  String get counselAccess_neutral;

  /// No description provided for @counselAccess_professional.
  ///
  /// In en, this message translates to:
  /// **'Counsel Access'**
  String get counselAccess_professional;

  /// No description provided for @counselAccess_legal.
  ///
  /// In en, this message translates to:
  /// **'Counsel Access'**
  String get counselAccess_legal;

  /// No description provided for @compilingAttorneyBrief_neutral.
  ///
  /// In en, this message translates to:
  /// **'Compiling Attorney Brief'**
  String get compilingAttorneyBrief_neutral;

  /// No description provided for @compilingAttorneyBrief_professional.
  ///
  /// In en, this message translates to:
  /// **'Compiling Attorney Brief'**
  String get compilingAttorneyBrief_professional;

  /// No description provided for @compilingAttorneyBrief_legal.
  ///
  /// In en, this message translates to:
  /// **'Compiling Attorney Brief'**
  String get compilingAttorneyBrief_legal;

  /// No description provided for @counselWorkspace_neutral.
  ///
  /// In en, this message translates to:
  /// **'Counsel Workspace'**
  String get counselWorkspace_neutral;

  /// No description provided for @counselWorkspace_professional.
  ///
  /// In en, this message translates to:
  /// **'Counsel Workspace'**
  String get counselWorkspace_professional;

  /// No description provided for @counselWorkspace_legal.
  ///
  /// In en, this message translates to:
  /// **'Counsel Workspace'**
  String get counselWorkspace_legal;

  /// No description provided for @generateCourtSummaryAttorneyBrief_neutral.
  ///
  /// In en, this message translates to:
  /// **'Generate Court Summary Attorney Brief'**
  String get generateCourtSummaryAttorneyBrief_neutral;

  /// No description provided for @generateCourtSummaryAttorneyBrief_professional.
  ///
  /// In en, this message translates to:
  /// **'Generate Court Summary Attorney Brief'**
  String get generateCourtSummaryAttorneyBrief_professional;

  /// No description provided for @generateCourtSummaryAttorneyBrief_legal.
  ///
  /// In en, this message translates to:
  /// **'Generate Court Summary Attorney Brief'**
  String get generateCourtSummaryAttorneyBrief_legal;

  /// No description provided for @openFullMessageLog_neutral.
  ///
  /// In en, this message translates to:
  /// **'Open Full Message Log'**
  String get openFullMessageLog_neutral;

  /// No description provided for @openFullMessageLog_professional.
  ///
  /// In en, this message translates to:
  /// **'Open Full Message Log'**
  String get openFullMessageLog_professional;

  /// No description provided for @openFullMessageLog_legal.
  ///
  /// In en, this message translates to:
  /// **'Open Full Message Log'**
  String get openFullMessageLog_legal;

  /// No description provided for @openUnifiedTimeline_neutral.
  ///
  /// In en, this message translates to:
  /// **'Open Unified Timeline'**
  String get openUnifiedTimeline_neutral;

  /// No description provided for @openUnifiedTimeline_professional.
  ///
  /// In en, this message translates to:
  /// **'Open Unified Timeline'**
  String get openUnifiedTimeline_professional;

  /// No description provided for @openUnifiedTimeline_legal.
  ///
  /// In en, this message translates to:
  /// **'Open Unified Timeline'**
  String get openUnifiedTimeline_legal;

  /// No description provided for @missedOverdueExchanges_neutral.
  ///
  /// In en, this message translates to:
  /// **'Missed or overdue exchanges'**
  String get missedOverdueExchanges_neutral;

  /// No description provided for @missedOverdueExchanges_professional.
  ///
  /// In en, this message translates to:
  /// **'Exchanges not completed on schedule'**
  String get missedOverdueExchanges_professional;

  /// No description provided for @missedOverdueExchanges_legal.
  ///
  /// In en, this message translates to:
  /// **'Scheduled exchanges not completed as documented'**
  String get missedOverdueExchanges_legal;

  /// No description provided for @unpaidSharedExpenses_neutral.
  ///
  /// In en, this message translates to:
  /// **'Unpaid Shared Expenses'**
  String get unpaidSharedExpenses_neutral;

  /// No description provided for @unpaidSharedExpenses_professional.
  ///
  /// In en, this message translates to:
  /// **'Unpaid Shared Expenses'**
  String get unpaidSharedExpenses_professional;

  /// No description provided for @unpaidSharedExpenses_legal.
  ///
  /// In en, this message translates to:
  /// **'Unpaid Shared Expenses'**
  String get unpaidSharedExpenses_legal;

  /// No description provided for @caseCenter_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case Center'**
  String get caseCenter_neutral;

  /// No description provided for @caseCenter_professional.
  ///
  /// In en, this message translates to:
  /// **'Case Center'**
  String get caseCenter_professional;

  /// No description provided for @caseCenter_legal.
  ///
  /// In en, this message translates to:
  /// **'Case Center'**
  String get caseCenter_legal;

  /// No description provided for @summarySavedToYourCase_neutral.
  ///
  /// In en, this message translates to:
  /// **'Summary Saved To Your Case'**
  String get summarySavedToYourCase_neutral;

  /// No description provided for @summarySavedToYourCase_professional.
  ///
  /// In en, this message translates to:
  /// **'Summary Saved To Your Case'**
  String get summarySavedToYourCase_professional;

  /// No description provided for @summarySavedToYourCase_legal.
  ///
  /// In en, this message translates to:
  /// **'Summary Saved To Your Case'**
  String get summarySavedToYourCase_legal;

  /// No description provided for @caseSummary_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case Summary'**
  String get caseSummary_neutral;

  /// No description provided for @caseSummary_professional.
  ///
  /// In en, this message translates to:
  /// **'Case Summary'**
  String get caseSummary_professional;

  /// No description provided for @caseSummary_legal.
  ///
  /// In en, this message translates to:
  /// **'Case Summary'**
  String get caseSummary_legal;

  /// No description provided for @dateRangeOptional_neutral.
  ///
  /// In en, this message translates to:
  /// **'Date Range Optional'**
  String get dateRangeOptional_neutral;

  /// No description provided for @dateRangeOptional_professional.
  ///
  /// In en, this message translates to:
  /// **'Date Range Optional'**
  String get dateRangeOptional_professional;

  /// No description provided for @dateRangeOptional_legal.
  ///
  /// In en, this message translates to:
  /// **'Date Range Optional'**
  String get dateRangeOptional_legal;

  /// No description provided for @clearRange_neutral.
  ///
  /// In en, this message translates to:
  /// **'Clear Range'**
  String get clearRange_neutral;

  /// No description provided for @clearRange_professional.
  ///
  /// In en, this message translates to:
  /// **'Clear Range'**
  String get clearRange_professional;

  /// No description provided for @clearRange_legal.
  ///
  /// In en, this message translates to:
  /// **'Clear Range'**
  String get clearRange_legal;

  /// No description provided for @caseTimeline_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case Timeline'**
  String get caseTimeline_neutral;

  /// No description provided for @caseTimeline_professional.
  ///
  /// In en, this message translates to:
  /// **'Case Timeline'**
  String get caseTimeline_professional;

  /// No description provided for @caseTimeline_legal.
  ///
  /// In en, this message translates to:
  /// **'Case Timeline'**
  String get caseTimeline_legal;

  /// No description provided for @childAddedSuccessfully_neutral.
  ///
  /// In en, this message translates to:
  /// **'Child Added Successfully'**
  String get childAddedSuccessfully_neutral;

  /// No description provided for @childAddedSuccessfully_professional.
  ///
  /// In en, this message translates to:
  /// **'Child Added Successfully'**
  String get childAddedSuccessfully_professional;

  /// No description provided for @childAddedSuccessfully_legal.
  ///
  /// In en, this message translates to:
  /// **'Child Added Successfully'**
  String get childAddedSuccessfully_legal;

  /// No description provided for @removeChild_neutral.
  ///
  /// In en, this message translates to:
  /// **'Remove Child'**
  String get removeChild_neutral;

  /// No description provided for @removeChild_professional.
  ///
  /// In en, this message translates to:
  /// **'Remove Child'**
  String get removeChild_professional;

  /// No description provided for @removeChild_legal.
  ///
  /// In en, this message translates to:
  /// **'Remove Child'**
  String get removeChild_legal;

  /// No description provided for @remove_neutral.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove_neutral;

  /// No description provided for @remove_professional.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove_professional;

  /// No description provided for @remove_legal.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove_legal;

  /// No description provided for @addChild_neutral.
  ///
  /// In en, this message translates to:
  /// **'Add Child'**
  String get addChild_neutral;

  /// No description provided for @addChild_professional.
  ///
  /// In en, this message translates to:
  /// **'Add Child'**
  String get addChild_professional;

  /// No description provided for @addChild_legal.
  ///
  /// In en, this message translates to:
  /// **'Add Child'**
  String get addChild_legal;

  /// No description provided for @complianceReport_neutral.
  ///
  /// In en, this message translates to:
  /// **'Compliance Report'**
  String get complianceReport_neutral;

  /// No description provided for @complianceReport_professional.
  ///
  /// In en, this message translates to:
  /// **'Compliance Report'**
  String get complianceReport_professional;

  /// No description provided for @complianceReport_legal.
  ///
  /// In en, this message translates to:
  /// **'Compliance Report'**
  String get complianceReport_legal;

  /// No description provided for @openTimeline_neutral.
  ///
  /// In en, this message translates to:
  /// **'Open Timeline'**
  String get openTimeline_neutral;

  /// No description provided for @openTimeline_professional.
  ///
  /// In en, this message translates to:
  /// **'Open Timeline'**
  String get openTimeline_professional;

  /// No description provided for @openTimeline_legal.
  ///
  /// In en, this message translates to:
  /// **'Open Timeline'**
  String get openTimeline_legal;

  /// No description provided for @exportLabel_neutral.
  ///
  /// In en, this message translates to:
  /// **'Export Label'**
  String get exportLabel_neutral;

  /// No description provided for @exportLabel_professional.
  ///
  /// In en, this message translates to:
  /// **'Export Label'**
  String get exportLabel_professional;

  /// No description provided for @exportLabel_legal.
  ///
  /// In en, this message translates to:
  /// **'Export Label'**
  String get exportLabel_legal;

  /// No description provided for @compromiseCenter_neutral.
  ///
  /// In en, this message translates to:
  /// **'Compromise Center'**
  String get compromiseCenter_neutral;

  /// No description provided for @compromiseCenter_professional.
  ///
  /// In en, this message translates to:
  /// **'Compromise Center'**
  String get compromiseCenter_professional;

  /// No description provided for @compromiseCenter_legal.
  ///
  /// In en, this message translates to:
  /// **'Compromise Center'**
  String get compromiseCenter_legal;

  /// No description provided for @couldNotSendMessageTry_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could Not Send Message Try'**
  String get couldNotSendMessageTry_neutral;

  /// No description provided for @couldNotSendMessageTry_professional.
  ///
  /// In en, this message translates to:
  /// **'Could Not Send Message Try'**
  String get couldNotSendMessageTry_professional;

  /// No description provided for @couldNotSendMessageTry_legal.
  ///
  /// In en, this message translates to:
  /// **'Could Not Send Message Try'**
  String get couldNotSendMessageTry_legal;

  /// No description provided for @noAiSuggestionAvailableFor_neutral.
  ///
  /// In en, this message translates to:
  /// **'No Ai Suggestion Available For'**
  String get noAiSuggestionAvailableFor_neutral;

  /// No description provided for @noAiSuggestionAvailableFor_professional.
  ///
  /// In en, this message translates to:
  /// **'No Ai Suggestion Available For'**
  String get noAiSuggestionAvailableFor_professional;

  /// No description provided for @noAiSuggestionAvailableFor_legal.
  ///
  /// In en, this message translates to:
  /// **'No Ai Suggestion Available For'**
  String get noAiSuggestionAvailableFor_legal;

  /// No description provided for @generatingAttorneyBrief_neutral.
  ///
  /// In en, this message translates to:
  /// **'Generating Attorney Brief'**
  String get generatingAttorneyBrief_neutral;

  /// No description provided for @generatingAttorneyBrief_professional.
  ///
  /// In en, this message translates to:
  /// **'Generating Attorney Brief'**
  String get generatingAttorneyBrief_professional;

  /// No description provided for @generatingAttorneyBrief_legal.
  ///
  /// In en, this message translates to:
  /// **'Generating Attorney Brief'**
  String get generatingAttorneyBrief_legal;

  /// No description provided for @attorneyBriefSavedToLegal_neutral.
  ///
  /// In en, this message translates to:
  /// **'Attorney Brief Saved To Legal'**
  String get attorneyBriefSavedToLegal_neutral;

  /// No description provided for @attorneyBriefSavedToLegal_professional.
  ///
  /// In en, this message translates to:
  /// **'Attorney Brief Saved To Legal'**
  String get attorneyBriefSavedToLegal_professional;

  /// No description provided for @attorneyBriefSavedToLegal_legal.
  ///
  /// In en, this message translates to:
  /// **'Attorney Brief Saved To Legal'**
  String get attorneyBriefSavedToLegal_legal;

  /// No description provided for @addAFewMoreMessages_neutral.
  ///
  /// In en, this message translates to:
  /// **'Add A Few More Messages'**
  String get addAFewMoreMessages_neutral;

  /// No description provided for @addAFewMoreMessages_professional.
  ///
  /// In en, this message translates to:
  /// **'Add A Few More Messages'**
  String get addAFewMoreMessages_professional;

  /// No description provided for @addAFewMoreMessages_legal.
  ///
  /// In en, this message translates to:
  /// **'Add A Few More Messages'**
  String get addAFewMoreMessages_legal;

  /// No description provided for @close_neutral.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close_neutral;

  /// No description provided for @close_professional.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close_professional;

  /// No description provided for @close_legal.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close_legal;

  /// No description provided for @savingExtendedCaseSummary_neutral.
  ///
  /// In en, this message translates to:
  /// **'Saving Extended Case Summary'**
  String get savingExtendedCaseSummary_neutral;

  /// No description provided for @savingExtendedCaseSummary_professional.
  ///
  /// In en, this message translates to:
  /// **'Saving Extended Case Summary'**
  String get savingExtendedCaseSummary_professional;

  /// No description provided for @savingExtendedCaseSummary_legal.
  ///
  /// In en, this message translates to:
  /// **'Saving Extended Case Summary'**
  String get savingExtendedCaseSummary_legal;

  /// No description provided for @summarySavedToYourCase2_neutral.
  ///
  /// In en, this message translates to:
  /// **'Summary Saved To Your Case2'**
  String get summarySavedToYourCase2_neutral;

  /// No description provided for @summarySavedToYourCase2_professional.
  ///
  /// In en, this message translates to:
  /// **'Summary Saved To Your Case2'**
  String get summarySavedToYourCase2_professional;

  /// No description provided for @summarySavedToYourCase2_legal.
  ///
  /// In en, this message translates to:
  /// **'Summary Saved To Your Case2'**
  String get summarySavedToYourCase2_legal;

  /// No description provided for @markImportant_neutral.
  ///
  /// In en, this message translates to:
  /// **'Mark Important'**
  String get markImportant_neutral;

  /// No description provided for @markImportant_professional.
  ///
  /// In en, this message translates to:
  /// **'Mark Important'**
  String get markImportant_professional;

  /// No description provided for @markImportant_legal.
  ///
  /// In en, this message translates to:
  /// **'Mark Important'**
  String get markImportant_legal;

  /// No description provided for @highlightForReviewAndExports_neutral.
  ///
  /// In en, this message translates to:
  /// **'Highlight For Review And Exports'**
  String get highlightForReviewAndExports_neutral;

  /// No description provided for @highlightForReviewAndExports_professional.
  ///
  /// In en, this message translates to:
  /// **'Highlight For Review And Exports'**
  String get highlightForReviewAndExports_professional;

  /// No description provided for @highlightForReviewAndExports_legal.
  ///
  /// In en, this message translates to:
  /// **'Highlight For Review And Exports'**
  String get highlightForReviewAndExports_legal;

  /// No description provided for @markAsEvidence_neutral.
  ///
  /// In en, this message translates to:
  /// **'Mark As Evidence'**
  String get markAsEvidence_neutral;

  /// No description provided for @markAsEvidence_professional.
  ///
  /// In en, this message translates to:
  /// **'Mark As Evidence'**
  String get markAsEvidence_professional;

  /// No description provided for @markAsEvidence_legal.
  ///
  /// In en, this message translates to:
  /// **'Mark As Evidence'**
  String get markAsEvidence_legal;

  /// No description provided for @flagForDisclosureBundles_neutral.
  ///
  /// In en, this message translates to:
  /// **'Flag For Disclosure Bundles'**
  String get flagForDisclosureBundles_neutral;

  /// No description provided for @flagForDisclosureBundles_professional.
  ///
  /// In en, this message translates to:
  /// **'Flag For Disclosure Bundles'**
  String get flagForDisclosureBundles_professional;

  /// No description provided for @flagForDisclosureBundles_legal.
  ///
  /// In en, this message translates to:
  /// **'Flag For Disclosure Bundles'**
  String get flagForDisclosureBundles_legal;

  /// No description provided for @save_neutral.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save_neutral;

  /// No description provided for @save_professional.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save_professional;

  /// No description provided for @save_legal.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save_legal;

  /// No description provided for @exportPdfFullThread_neutral.
  ///
  /// In en, this message translates to:
  /// **'Export Pdf Full Thread'**
  String get exportPdfFullThread_neutral;

  /// No description provided for @exportPdfFullThread_professional.
  ///
  /// In en, this message translates to:
  /// **'Export Pdf Full Thread'**
  String get exportPdfFullThread_professional;

  /// No description provided for @exportPdfFullThread_legal.
  ///
  /// In en, this message translates to:
  /// **'Export Pdf Full Thread'**
  String get exportPdfFullThread_legal;

  /// No description provided for @exportPdfLast30Days_neutral.
  ///
  /// In en, this message translates to:
  /// **'Export Pdf Last30 Days'**
  String get exportPdfLast30Days_neutral;

  /// No description provided for @exportPdfLast30Days_professional.
  ///
  /// In en, this message translates to:
  /// **'Export Pdf Last30 Days'**
  String get exportPdfLast30Days_professional;

  /// No description provided for @exportPdfLast30Days_legal.
  ///
  /// In en, this message translates to:
  /// **'Export Pdf Last30 Days'**
  String get exportPdfLast30Days_legal;

  /// No description provided for @exportPdfFlaggedRiskOnly_neutral.
  ///
  /// In en, this message translates to:
  /// **'Export Pdf Flagged Risk Only'**
  String get exportPdfFlaggedRiskOnly_neutral;

  /// No description provided for @exportPdfFlaggedRiskOnly_professional.
  ///
  /// In en, this message translates to:
  /// **'Export Pdf Flagged Risk Only'**
  String get exportPdfFlaggedRiskOnly_professional;

  /// No description provided for @exportPdfFlaggedRiskOnly_legal.
  ///
  /// In en, this message translates to:
  /// **'Export Pdf Flagged Risk Only'**
  String get exportPdfFlaggedRiskOnly_legal;

  /// No description provided for @saveExtendedRecordToCase_neutral.
  ///
  /// In en, this message translates to:
  /// **'Save Extended Record To Case'**
  String get saveExtendedRecordToCase_neutral;

  /// No description provided for @saveExtendedRecordToCase_professional.
  ///
  /// In en, this message translates to:
  /// **'Save Extended Record To Case'**
  String get saveExtendedRecordToCase_professional;

  /// No description provided for @saveExtendedRecordToCase_legal.
  ///
  /// In en, this message translates to:
  /// **'Save Extended Record To Case'**
  String get saveExtendedRecordToCase_legal;

  /// No description provided for @sendAsWritten_neutral.
  ///
  /// In en, this message translates to:
  /// **'Send As Written'**
  String get sendAsWritten_neutral;

  /// No description provided for @sendAsWritten_professional.
  ///
  /// In en, this message translates to:
  /// **'Send As Written'**
  String get sendAsWritten_professional;

  /// No description provided for @sendAsWritten_legal.
  ///
  /// In en, this message translates to:
  /// **'Send As Written'**
  String get sendAsWritten_legal;

  /// No description provided for @useAiSuggestion_neutral.
  ///
  /// In en, this message translates to:
  /// **'Use Ai Suggestion'**
  String get useAiSuggestion_neutral;

  /// No description provided for @useAiSuggestion_professional.
  ///
  /// In en, this message translates to:
  /// **'Use Ai Suggestion'**
  String get useAiSuggestion_professional;

  /// No description provided for @useAiSuggestion_legal.
  ///
  /// In en, this message translates to:
  /// **'Use Ai Suggestion'**
  String get useAiSuggestion_legal;

  /// No description provided for @addressVerifiedForThisExchange_neutral.
  ///
  /// In en, this message translates to:
  /// **'Address Verified For This Exchange'**
  String get addressVerifiedForThisExchange_neutral;

  /// No description provided for @addressVerifiedForThisExchange_professional.
  ///
  /// In en, this message translates to:
  /// **'Address Verified For This Exchange'**
  String get addressVerifiedForThisExchange_professional;

  /// No description provided for @addressVerifiedForThisExchange_legal.
  ///
  /// In en, this message translates to:
  /// **'Address Verified For This Exchange'**
  String get addressVerifiedForThisExchange_legal;

  /// No description provided for @caseNotReadyFinishWorkspace_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case Not Ready Finish Workspace'**
  String get caseNotReadyFinishWorkspace_neutral;

  /// No description provided for @caseNotReadyFinishWorkspace_professional.
  ///
  /// In en, this message translates to:
  /// **'Case Not Ready Finish Workspace'**
  String get caseNotReadyFinishWorkspace_professional;

  /// No description provided for @caseNotReadyFinishWorkspace_legal.
  ///
  /// In en, this message translates to:
  /// **'Case Not Ready Finish Workspace'**
  String get caseNotReadyFinishWorkspace_legal;

  /// No description provided for @addAChildToYour_neutral.
  ///
  /// In en, this message translates to:
  /// **'Add A Child To Your'**
  String get addAChildToYour_neutral;

  /// No description provided for @addAChildToYour_professional.
  ///
  /// In en, this message translates to:
  /// **'Add A Child To Your'**
  String get addAChildToYour_professional;

  /// No description provided for @addAChildToYour_legal.
  ///
  /// In en, this message translates to:
  /// **'Add A Child To Your'**
  String get addAChildToYour_legal;

  /// No description provided for @completeAllSectionsIncludingA_neutral.
  ///
  /// In en, this message translates to:
  /// **'Complete All Sections Including A'**
  String get completeAllSectionsIncludingA_neutral;

  /// No description provided for @completeAllSectionsIncludingA_professional.
  ///
  /// In en, this message translates to:
  /// **'Complete All Sections Including A'**
  String get completeAllSectionsIncludingA_professional;

  /// No description provided for @completeAllSectionsIncludingA_legal.
  ///
  /// In en, this message translates to:
  /// **'Complete All Sections Including A'**
  String get completeAllSectionsIncludingA_legal;

  /// No description provided for @scheduleExchange_neutral.
  ///
  /// In en, this message translates to:
  /// **'Schedule Exchange'**
  String get scheduleExchange_neutral;

  /// No description provided for @scheduleExchange_professional.
  ///
  /// In en, this message translates to:
  /// **'Schedule Exchange'**
  String get scheduleExchange_professional;

  /// No description provided for @scheduleExchange_legal.
  ///
  /// In en, this message translates to:
  /// **'Schedule Exchange'**
  String get scheduleExchange_legal;

  /// No description provided for @enterAddressManually_neutral.
  ///
  /// In en, this message translates to:
  /// **'Enter Address Manually'**
  String get enterAddressManually_neutral;

  /// No description provided for @enterAddressManually_professional.
  ///
  /// In en, this message translates to:
  /// **'Enter Address Manually'**
  String get enterAddressManually_professional;

  /// No description provided for @enterAddressManually_legal.
  ///
  /// In en, this message translates to:
  /// **'Enter Address Manually'**
  String get enterAddressManually_legal;

  /// No description provided for @useAddressSearch_neutral.
  ///
  /// In en, this message translates to:
  /// **'Use Address Search'**
  String get useAddressSearch_neutral;

  /// No description provided for @useAddressSearch_professional.
  ///
  /// In en, this message translates to:
  /// **'Use Address Search'**
  String get useAddressSearch_professional;

  /// No description provided for @useAddressSearch_legal.
  ///
  /// In en, this message translates to:
  /// **'Use Address Search'**
  String get useAddressSearch_legal;

  /// No description provided for @verifyAddress_neutral.
  ///
  /// In en, this message translates to:
  /// **'Verify Address'**
  String get verifyAddress_neutral;

  /// No description provided for @verifyAddress_professional.
  ///
  /// In en, this message translates to:
  /// **'Verify Address'**
  String get verifyAddress_professional;

  /// No description provided for @verifyAddress_legal.
  ///
  /// In en, this message translates to:
  /// **'Verify Address'**
  String get verifyAddress_legal;

  /// No description provided for @caseComplianceAlert_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case Compliance Alert'**
  String get caseComplianceAlert_neutral;

  /// No description provided for @caseComplianceAlert_professional.
  ///
  /// In en, this message translates to:
  /// **'Case Compliance Alert'**
  String get caseComplianceAlert_professional;

  /// No description provided for @caseComplianceAlert_legal.
  ///
  /// In en, this message translates to:
  /// **'Case Compliance Alert'**
  String get caseComplianceAlert_legal;

  /// No description provided for @custodyRisk_neutral.
  ///
  /// In en, this message translates to:
  /// **'Custody Risk'**
  String get custodyRisk_neutral;

  /// No description provided for @custodyRisk_professional.
  ///
  /// In en, this message translates to:
  /// **'Custody Risk'**
  String get custodyRisk_professional;

  /// No description provided for @custodyRisk_legal.
  ///
  /// In en, this message translates to:
  /// **'Custody Risk'**
  String get custodyRisk_legal;

  /// No description provided for @viewProPlans_neutral.
  ///
  /// In en, this message translates to:
  /// **'View Pro Plans'**
  String get viewProPlans_neutral;

  /// No description provided for @viewProPlans_professional.
  ///
  /// In en, this message translates to:
  /// **'View Pro Plans'**
  String get viewProPlans_professional;

  /// No description provided for @viewProPlans_legal.
  ///
  /// In en, this message translates to:
  /// **'View Pro Plans'**
  String get viewProPlans_legal;

  /// No description provided for @linkYourCaseInWorkspace_neutral.
  ///
  /// In en, this message translates to:
  /// **'Link Your Case In Workspace'**
  String get linkYourCaseInWorkspace_neutral;

  /// No description provided for @linkYourCaseInWorkspace_professional.
  ///
  /// In en, this message translates to:
  /// **'Link Your Case In Workspace'**
  String get linkYourCaseInWorkspace_professional;

  /// No description provided for @linkYourCaseInWorkspace_legal.
  ///
  /// In en, this message translates to:
  /// **'Link Your Case In Workspace'**
  String get linkYourCaseInWorkspace_legal;

  /// No description provided for @noUpcomingExchangeLocationAvailable_neutral.
  ///
  /// In en, this message translates to:
  /// **'No Upcoming Exchange Location Available'**
  String get noUpcomingExchangeLocationAvailable_neutral;

  /// No description provided for @noUpcomingExchangeLocationAvailable_professional.
  ///
  /// In en, this message translates to:
  /// **'No Upcoming Exchange Location Available'**
  String get noUpcomingExchangeLocationAvailable_professional;

  /// No description provided for @noUpcomingExchangeLocationAvailable_legal.
  ///
  /// In en, this message translates to:
  /// **'No Upcoming Exchange Location Available'**
  String get noUpcomingExchangeLocationAvailable_legal;

  /// No description provided for @navigateToExchangeLocation_neutral.
  ///
  /// In en, this message translates to:
  /// **'Navigate To Exchange Location'**
  String get navigateToExchangeLocation_neutral;

  /// No description provided for @navigateToExchangeLocation_professional.
  ///
  /// In en, this message translates to:
  /// **'Navigate To Exchange Location'**
  String get navigateToExchangeLocation_professional;

  /// No description provided for @navigateToExchangeLocation_legal.
  ///
  /// In en, this message translates to:
  /// **'Navigate To Exchange Location'**
  String get navigateToExchangeLocation_legal;

  /// No description provided for @openMaps_neutral.
  ///
  /// In en, this message translates to:
  /// **'Open Maps'**
  String get openMaps_neutral;

  /// No description provided for @openMaps_professional.
  ///
  /// In en, this message translates to:
  /// **'Open Maps'**
  String get openMaps_professional;

  /// No description provided for @openMaps_legal.
  ///
  /// In en, this message translates to:
  /// **'Open Maps'**
  String get openMaps_legal;

  /// No description provided for @couldNotOpenMapsOn_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Maps On'**
  String get couldNotOpenMapsOn_neutral;

  /// No description provided for @couldNotOpenMapsOn_professional.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Maps On'**
  String get couldNotOpenMapsOn_professional;

  /// No description provided for @couldNotOpenMapsOn_legal.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Maps On'**
  String get couldNotOpenMapsOn_legal;

  /// No description provided for @couldNotOpenMaps_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Maps'**
  String get couldNotOpenMaps_neutral;

  /// No description provided for @couldNotOpenMaps_professional.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Maps'**
  String get couldNotOpenMaps_professional;

  /// No description provided for @couldNotOpenMaps_legal.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Maps'**
  String get couldNotOpenMaps_legal;

  /// No description provided for @viewAllThreads_neutral.
  ///
  /// In en, this message translates to:
  /// **'View All Threads'**
  String get viewAllThreads_neutral;

  /// No description provided for @viewAllThreads_professional.
  ///
  /// In en, this message translates to:
  /// **'View All Threads'**
  String get viewAllThreads_professional;

  /// No description provided for @viewAllThreads_legal.
  ///
  /// In en, this message translates to:
  /// **'View All Threads'**
  String get viewAllThreads_legal;

  /// No description provided for @documentUploaded_neutral.
  ///
  /// In en, this message translates to:
  /// **'Document Uploaded'**
  String get documentUploaded_neutral;

  /// No description provided for @documentUploaded_professional.
  ///
  /// In en, this message translates to:
  /// **'Document Uploaded'**
  String get documentUploaded_professional;

  /// No description provided for @documentUploaded_legal.
  ///
  /// In en, this message translates to:
  /// **'Document Uploaded'**
  String get documentUploaded_legal;

  /// No description provided for @caseDocuments_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case Documents'**
  String get caseDocuments_neutral;

  /// No description provided for @caseDocuments_professional.
  ///
  /// In en, this message translates to:
  /// **'Case Documents'**
  String get caseDocuments_professional;

  /// No description provided for @caseDocuments_legal.
  ///
  /// In en, this message translates to:
  /// **'Case Documents'**
  String get caseDocuments_legal;

  /// No description provided for @uploadDocument_neutral.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get uploadDocument_neutral;

  /// No description provided for @uploadDocument_professional.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get uploadDocument_professional;

  /// No description provided for @uploadDocument_legal.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get uploadDocument_legal;

  /// No description provided for @viewTimeline_neutral.
  ///
  /// In en, this message translates to:
  /// **'View Timeline'**
  String get viewTimeline_neutral;

  /// No description provided for @viewTimeline_professional.
  ///
  /// In en, this message translates to:
  /// **'View Timeline'**
  String get viewTimeline_professional;

  /// No description provided for @viewTimeline_legal.
  ///
  /// In en, this message translates to:
  /// **'View Timeline'**
  String get viewTimeline_legal;

  /// No description provided for @exportRecord_neutral.
  ///
  /// In en, this message translates to:
  /// **'Export Record'**
  String get exportRecord_neutral;

  /// No description provided for @exportRecord_professional.
  ///
  /// In en, this message translates to:
  /// **'Export Record'**
  String get exportRecord_professional;

  /// No description provided for @exportRecord_legal.
  ///
  /// In en, this message translates to:
  /// **'Export Record'**
  String get exportRecord_legal;

  /// No description provided for @done_neutral.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done_neutral;

  /// No description provided for @done_professional.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done_professional;

  /// No description provided for @done_legal.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done_legal;

  /// No description provided for @notSignedInPleaseSign_neutral.
  ///
  /// In en, this message translates to:
  /// **'Not Signed In Please Sign'**
  String get notSignedInPleaseSign_neutral;

  /// No description provided for @notSignedInPleaseSign_professional.
  ///
  /// In en, this message translates to:
  /// **'Not Signed In Please Sign'**
  String get notSignedInPleaseSign_professional;

  /// No description provided for @notSignedInPleaseSign_legal.
  ///
  /// In en, this message translates to:
  /// **'Not Signed In Please Sign'**
  String get notSignedInPleaseSign_legal;

  /// No description provided for @exchangeCheckin_neutral.
  ///
  /// In en, this message translates to:
  /// **'Exchange Checkin'**
  String get exchangeCheckin_neutral;

  /// No description provided for @exchangeCheckin_professional.
  ///
  /// In en, this message translates to:
  /// **'Exchange Checkin'**
  String get exchangeCheckin_professional;

  /// No description provided for @exchangeCheckin_legal.
  ///
  /// In en, this message translates to:
  /// **'Exchange Checkin'**
  String get exchangeCheckin_legal;

  /// No description provided for @logManualCheckin_neutral.
  ///
  /// In en, this message translates to:
  /// **'Log Manual Checkin'**
  String get logManualCheckin_neutral;

  /// No description provided for @logManualCheckin_professional.
  ///
  /// In en, this message translates to:
  /// **'Log Manual Checkin'**
  String get logManualCheckin_professional;

  /// No description provided for @logManualCheckin_legal.
  ///
  /// In en, this message translates to:
  /// **'Log Manual Checkin'**
  String get logManualCheckin_legal;

  /// No description provided for @detectingYourLocation_neutral.
  ///
  /// In en, this message translates to:
  /// **'Detecting Your Location'**
  String get detectingYourLocation_neutral;

  /// No description provided for @detectingYourLocation_professional.
  ///
  /// In en, this message translates to:
  /// **'Detecting Your Location'**
  String get detectingYourLocation_professional;

  /// No description provided for @detectingYourLocation_legal.
  ///
  /// In en, this message translates to:
  /// **'Detecting Your Location'**
  String get detectingYourLocation_legal;

  /// No description provided for @openNavigation_neutral.
  ///
  /// In en, this message translates to:
  /// **'Open Navigation'**
  String get openNavigation_neutral;

  /// No description provided for @openNavigation_professional.
  ///
  /// In en, this message translates to:
  /// **'Open Navigation'**
  String get openNavigation_professional;

  /// No description provided for @openNavigation_legal.
  ///
  /// In en, this message translates to:
  /// **'Open Navigation'**
  String get openNavigation_legal;

  /// No description provided for @refreshLocation_neutral.
  ///
  /// In en, this message translates to:
  /// **'Refresh Location'**
  String get refreshLocation_neutral;

  /// No description provided for @refreshLocation_professional.
  ///
  /// In en, this message translates to:
  /// **'Refresh Location'**
  String get refreshLocation_professional;

  /// No description provided for @refreshLocation_legal.
  ///
  /// In en, this message translates to:
  /// **'Refresh Location'**
  String get refreshLocation_legal;

  /// No description provided for @startCheckin_neutral.
  ///
  /// In en, this message translates to:
  /// **'Start Checkin'**
  String get startCheckin_neutral;

  /// No description provided for @startCheckin_professional.
  ///
  /// In en, this message translates to:
  /// **'Start Checkin'**
  String get startCheckin_professional;

  /// No description provided for @startCheckin_legal.
  ///
  /// In en, this message translates to:
  /// **'Start Checkin'**
  String get startCheckin_legal;

  /// No description provided for @back_neutral.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back_neutral;

  /// No description provided for @back_professional.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back_professional;

  /// No description provided for @back_legal.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back_legal;

  /// No description provided for @refreshGps_neutral.
  ///
  /// In en, this message translates to:
  /// **'Refresh Gps'**
  String get refreshGps_neutral;

  /// No description provided for @refreshGps_professional.
  ///
  /// In en, this message translates to:
  /// **'Refresh Gps'**
  String get refreshGps_professional;

  /// No description provided for @refreshGps_legal.
  ///
  /// In en, this message translates to:
  /// **'Refresh Gps'**
  String get refreshGps_legal;

  /// No description provided for @completeCheckin_neutral.
  ///
  /// In en, this message translates to:
  /// **'Complete Checkin'**
  String get completeCheckin_neutral;

  /// No description provided for @completeCheckin_professional.
  ///
  /// In en, this message translates to:
  /// **'Complete Checkin'**
  String get completeCheckin_professional;

  /// No description provided for @completeCheckin_legal.
  ///
  /// In en, this message translates to:
  /// **'Complete Checkin'**
  String get completeCheckin_legal;

  /// No description provided for @navigateToLocation_neutral.
  ///
  /// In en, this message translates to:
  /// **'Navigate To Location'**
  String get navigateToLocation_neutral;

  /// No description provided for @navigateToLocation_professional.
  ///
  /// In en, this message translates to:
  /// **'Navigate To Location'**
  String get navigateToLocation_professional;

  /// No description provided for @navigateToLocation_legal.
  ///
  /// In en, this message translates to:
  /// **'Navigate To Location'**
  String get navigateToLocation_legal;

  /// No description provided for @sharedExpenses_neutral.
  ///
  /// In en, this message translates to:
  /// **'Shared Expenses'**
  String get sharedExpenses_neutral;

  /// No description provided for @sharedExpenses_professional.
  ///
  /// In en, this message translates to:
  /// **'Shared Expenses'**
  String get sharedExpenses_professional;

  /// No description provided for @sharedExpenses_legal.
  ///
  /// In en, this message translates to:
  /// **'Shared Expenses'**
  String get sharedExpenses_legal;

  /// No description provided for @review_neutral.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review_neutral;

  /// No description provided for @review_professional.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review_professional;

  /// No description provided for @review_legal.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review_legal;

  /// No description provided for @markUnpaid_neutral.
  ///
  /// In en, this message translates to:
  /// **'Mark Unpaid'**
  String get markUnpaid_neutral;

  /// No description provided for @markUnpaid_professional.
  ///
  /// In en, this message translates to:
  /// **'Mark Unpaid'**
  String get markUnpaid_professional;

  /// No description provided for @markUnpaid_legal.
  ///
  /// In en, this message translates to:
  /// **'Mark Unpaid'**
  String get markUnpaid_legal;

  /// No description provided for @welcomeToParentledger_neutral.
  ///
  /// In en, this message translates to:
  /// **'Welcome To Parentledger'**
  String get welcomeToParentledger_neutral;

  /// No description provided for @welcomeToParentledger_professional.
  ///
  /// In en, this message translates to:
  /// **'Welcome To Parentledger'**
  String get welcomeToParentledger_professional;

  /// No description provided for @welcomeToParentledger_legal.
  ///
  /// In en, this message translates to:
  /// **'Welcome To Parentledger'**
  String get welcomeToParentledger_legal;

  /// No description provided for @startUsingDashboard_neutral.
  ///
  /// In en, this message translates to:
  /// **'Start Using Dashboard'**
  String get startUsingDashboard_neutral;

  /// No description provided for @startUsingDashboard_professional.
  ///
  /// In en, this message translates to:
  /// **'Start Using Dashboard'**
  String get startUsingDashboard_professional;

  /// No description provided for @startUsingDashboard_legal.
  ///
  /// In en, this message translates to:
  /// **'Start Using Dashboard'**
  String get startUsingDashboard_legal;

  /// No description provided for @helpSupport_neutral.
  ///
  /// In en, this message translates to:
  /// **'Help Support'**
  String get helpSupport_neutral;

  /// No description provided for @helpSupport_professional.
  ///
  /// In en, this message translates to:
  /// **'Help Support'**
  String get helpSupport_professional;

  /// No description provided for @helpSupport_legal.
  ///
  /// In en, this message translates to:
  /// **'Help Support'**
  String get helpSupport_legal;

  /// No description provided for @couldNotOpenEmailApp_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Email App'**
  String get couldNotOpenEmailApp_neutral;

  /// No description provided for @couldNotOpenEmailApp_professional.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Email App'**
  String get couldNotOpenEmailApp_professional;

  /// No description provided for @couldNotOpenEmailApp_legal.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Email App'**
  String get couldNotOpenEmailApp_legal;

  /// No description provided for @aiChatSupportIsOn_neutral.
  ///
  /// In en, this message translates to:
  /// **'Ai Chat Support Is On'**
  String get aiChatSupportIsOn_neutral;

  /// No description provided for @aiChatSupportIsOn_professional.
  ///
  /// In en, this message translates to:
  /// **'Ai Chat Support Is On'**
  String get aiChatSupportIsOn_professional;

  /// No description provided for @aiChatSupportIsOn_legal.
  ///
  /// In en, this message translates to:
  /// **'Ai Chat Support Is On'**
  String get aiChatSupportIsOn_legal;

  /// No description provided for @generateInviteLink_neutral.
  ///
  /// In en, this message translates to:
  /// **'Generate Invite Link'**
  String get generateInviteLink_neutral;

  /// No description provided for @generateInviteLink_professional.
  ///
  /// In en, this message translates to:
  /// **'Generate Invite Link'**
  String get generateInviteLink_professional;

  /// No description provided for @generateInviteLink_legal.
  ///
  /// In en, this message translates to:
  /// **'Generate Invite Link'**
  String get generateInviteLink_legal;

  /// No description provided for @inviteIdCopied_neutral.
  ///
  /// In en, this message translates to:
  /// **'Invite Id Copied'**
  String get inviteIdCopied_neutral;

  /// No description provided for @inviteIdCopied_professional.
  ///
  /// In en, this message translates to:
  /// **'Invite Id Copied'**
  String get inviteIdCopied_professional;

  /// No description provided for @inviteIdCopied_legal.
  ///
  /// In en, this message translates to:
  /// **'Invite Id Copied'**
  String get inviteIdCopied_legal;

  /// No description provided for @copyInviteId_neutral.
  ///
  /// In en, this message translates to:
  /// **'Copy Invite Id'**
  String get copyInviteId_neutral;

  /// No description provided for @copyInviteId_professional.
  ///
  /// In en, this message translates to:
  /// **'Copy Invite Id'**
  String get copyInviteId_professional;

  /// No description provided for @copyInviteId_legal.
  ///
  /// In en, this message translates to:
  /// **'Copy Invite Id'**
  String get copyInviteId_legal;

  /// No description provided for @couldNotContinuePleaseTry_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could Not Continue Please Try'**
  String get couldNotContinuePleaseTry_neutral;

  /// No description provided for @couldNotContinuePleaseTry_professional.
  ///
  /// In en, this message translates to:
  /// **'Could Not Continue Please Try'**
  String get couldNotContinuePleaseTry_professional;

  /// No description provided for @couldNotContinuePleaseTry_legal.
  ///
  /// In en, this message translates to:
  /// **'Could Not Continue Please Try'**
  String get couldNotContinuePleaseTry_legal;

  /// No description provided for @contactsPermissionIsRequiredTo_neutral.
  ///
  /// In en, this message translates to:
  /// **'Contacts Permission Is Required To'**
  String get contactsPermissionIsRequiredTo_neutral;

  /// No description provided for @contactsPermissionIsRequiredTo_professional.
  ///
  /// In en, this message translates to:
  /// **'Contacts Permission Is Required To'**
  String get contactsPermissionIsRequiredTo_professional;

  /// No description provided for @contactsPermissionIsRequiredTo_legal.
  ///
  /// In en, this message translates to:
  /// **'Contacts Permission Is Required To'**
  String get contactsPermissionIsRequiredTo_legal;

  /// No description provided for @importFromContacts_neutral.
  ///
  /// In en, this message translates to:
  /// **'Import From Contacts'**
  String get importFromContacts_neutral;

  /// No description provided for @importFromContacts_professional.
  ///
  /// In en, this message translates to:
  /// **'Import From Contacts'**
  String get importFromContacts_professional;

  /// No description provided for @importFromContacts_legal.
  ///
  /// In en, this message translates to:
  /// **'Import From Contacts'**
  String get importFromContacts_legal;

  /// No description provided for @copiedToClipboard_neutral.
  ///
  /// In en, this message translates to:
  /// **'Copied To Clipboard'**
  String get copiedToClipboard_neutral;

  /// No description provided for @copiedToClipboard_professional.
  ///
  /// In en, this message translates to:
  /// **'Copied To Clipboard'**
  String get copiedToClipboard_professional;

  /// No description provided for @copiedToClipboard_legal.
  ///
  /// In en, this message translates to:
  /// **'Copied To Clipboard'**
  String get copiedToClipboard_legal;

  /// No description provided for @pdfExportComingSoon_neutral.
  ///
  /// In en, this message translates to:
  /// **'Pdf Export Coming Soon'**
  String get pdfExportComingSoon_neutral;

  /// No description provided for @pdfExportComingSoon_professional.
  ///
  /// In en, this message translates to:
  /// **'Pdf Export Coming Soon'**
  String get pdfExportComingSoon_professional;

  /// No description provided for @pdfExportComingSoon_legal.
  ///
  /// In en, this message translates to:
  /// **'Pdf Export Coming Soon'**
  String get pdfExportComingSoon_legal;

  /// No description provided for @courtCommunicationSummary_neutral.
  ///
  /// In en, this message translates to:
  /// **'Court Communication Summary'**
  String get courtCommunicationSummary_neutral;

  /// No description provided for @courtCommunicationSummary_professional.
  ///
  /// In en, this message translates to:
  /// **'Communication summary'**
  String get courtCommunicationSummary_professional;

  /// No description provided for @courtCommunicationSummary_legal.
  ///
  /// In en, this message translates to:
  /// **'Chronological communication summary'**
  String get courtCommunicationSummary_legal;

  /// No description provided for @summaryCopiedToClipboard_neutral.
  ///
  /// In en, this message translates to:
  /// **'Summary Copied To Clipboard'**
  String get summaryCopiedToClipboard_neutral;

  /// No description provided for @summaryCopiedToClipboard_professional.
  ///
  /// In en, this message translates to:
  /// **'Summary Copied To Clipboard'**
  String get summaryCopiedToClipboard_professional;

  /// No description provided for @summaryCopiedToClipboard_legal.
  ///
  /// In en, this message translates to:
  /// **'Summary Copied To Clipboard'**
  String get summaryCopiedToClipboard_legal;

  /// No description provided for @retry_neutral.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry_neutral;

  /// No description provided for @retry_professional.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry_professional;

  /// No description provided for @retry_legal.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry_legal;

  /// No description provided for @setUpThreads_neutral.
  ///
  /// In en, this message translates to:
  /// **'Set Up Threads'**
  String get setUpThreads_neutral;

  /// No description provided for @setUpThreads_professional.
  ///
  /// In en, this message translates to:
  /// **'Set Up Threads'**
  String get setUpThreads_professional;

  /// No description provided for @setUpThreads_legal.
  ///
  /// In en, this message translates to:
  /// **'Set Up Threads'**
  String get setUpThreads_legal;

  /// No description provided for @currentStep_neutral.
  ///
  /// In en, this message translates to:
  /// **'Current Step'**
  String get currentStep_neutral;

  /// No description provided for @currentStep_professional.
  ///
  /// In en, this message translates to:
  /// **'Current Step'**
  String get currentStep_professional;

  /// No description provided for @currentStep_legal.
  ///
  /// In en, this message translates to:
  /// **'Current Step'**
  String get currentStep_legal;

  /// No description provided for @continueWithLimitedAccess_neutral.
  ///
  /// In en, this message translates to:
  /// **'Continue With Limited Access'**
  String get continueWithLimitedAccess_neutral;

  /// No description provided for @continueWithLimitedAccess_professional.
  ///
  /// In en, this message translates to:
  /// **'Continue With Limited Access'**
  String get continueWithLimitedAccess_professional;

  /// No description provided for @continueWithLimitedAccess_legal.
  ///
  /// In en, this message translates to:
  /// **'Continue With Limited Access'**
  String get continueWithLimitedAccess_legal;

  /// No description provided for @takePhoto_neutral.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto_neutral;

  /// No description provided for @takePhoto_professional.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto_professional;

  /// No description provided for @takePhoto_legal.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto_legal;

  /// No description provided for @chooseFromGallery_neutral.
  ///
  /// In en, this message translates to:
  /// **'Choose From Gallery'**
  String get chooseFromGallery_neutral;

  /// No description provided for @chooseFromGallery_professional.
  ///
  /// In en, this message translates to:
  /// **'Choose From Gallery'**
  String get chooseFromGallery_professional;

  /// No description provided for @chooseFromGallery_legal.
  ///
  /// In en, this message translates to:
  /// **'Choose From Gallery'**
  String get chooseFromGallery_legal;

  /// No description provided for @profilePhotoUpdated_neutral.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo Updated'**
  String get profilePhotoUpdated_neutral;

  /// No description provided for @profilePhotoUpdated_professional.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo Updated'**
  String get profilePhotoUpdated_professional;

  /// No description provided for @profilePhotoUpdated_legal.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo Updated'**
  String get profilePhotoUpdated_legal;

  /// No description provided for @uploadFailed_neutral.
  ///
  /// In en, this message translates to:
  /// **'Upload Failed'**
  String get uploadFailed_neutral;

  /// No description provided for @uploadFailed_professional.
  ///
  /// In en, this message translates to:
  /// **'Upload Failed'**
  String get uploadFailed_professional;

  /// No description provided for @uploadFailed_legal.
  ///
  /// In en, this message translates to:
  /// **'Upload Failed'**
  String get uploadFailed_legal;

  /// No description provided for @couldNotOpenSubscriptionSettings_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Subscription Settings'**
  String get couldNotOpenSubscriptionSettings_neutral;

  /// No description provided for @couldNotOpenSubscriptionSettings_professional.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Subscription Settings'**
  String get couldNotOpenSubscriptionSettings_professional;

  /// No description provided for @couldNotOpenSubscriptionSettings_legal.
  ///
  /// In en, this message translates to:
  /// **'Could Not Open Subscription Settings'**
  String get couldNotOpenSubscriptionSettings_legal;

  /// No description provided for @inviteCancelled_neutral.
  ///
  /// In en, this message translates to:
  /// **'Invite Cancelled'**
  String get inviteCancelled_neutral;

  /// No description provided for @inviteCancelled_professional.
  ///
  /// In en, this message translates to:
  /// **'Invite Cancelled'**
  String get inviteCancelled_professional;

  /// No description provided for @inviteCancelled_legal.
  ///
  /// In en, this message translates to:
  /// **'Invite Cancelled'**
  String get inviteCancelled_legal;

  /// No description provided for @notSignedIn_neutral.
  ///
  /// In en, this message translates to:
  /// **'Not Signed In'**
  String get notSignedIn_neutral;

  /// No description provided for @notSignedIn_professional.
  ///
  /// In en, this message translates to:
  /// **'Not Signed In'**
  String get notSignedIn_professional;

  /// No description provided for @notSignedIn_legal.
  ///
  /// In en, this message translates to:
  /// **'Not Signed In'**
  String get notSignedIn_legal;

  /// No description provided for @cancelInvite_neutral.
  ///
  /// In en, this message translates to:
  /// **'Cancel Invite'**
  String get cancelInvite_neutral;

  /// No description provided for @cancelInvite_professional.
  ///
  /// In en, this message translates to:
  /// **'Cancel Invite'**
  String get cancelInvite_professional;

  /// No description provided for @cancelInvite_legal.
  ///
  /// In en, this message translates to:
  /// **'Cancel Invite'**
  String get cancelInvite_legal;

  /// No description provided for @resend_neutral.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend_neutral;

  /// No description provided for @resend_professional.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend_professional;

  /// No description provided for @resend_legal.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend_legal;

  /// No description provided for @managePlan_neutral.
  ///
  /// In en, this message translates to:
  /// **'Manage Plan'**
  String get managePlan_neutral;

  /// No description provided for @managePlan_professional.
  ///
  /// In en, this message translates to:
  /// **'Manage Plan'**
  String get managePlan_professional;

  /// No description provided for @managePlan_legal.
  ///
  /// In en, this message translates to:
  /// **'Manage Plan'**
  String get managePlan_legal;

  /// No description provided for @cancelSubscription_neutral.
  ///
  /// In en, this message translates to:
  /// **'Cancel Subscription'**
  String get cancelSubscription_neutral;

  /// No description provided for @cancelSubscription_professional.
  ///
  /// In en, this message translates to:
  /// **'Cancel Subscription'**
  String get cancelSubscription_professional;

  /// No description provided for @cancelSubscription_legal.
  ///
  /// In en, this message translates to:
  /// **'Cancel Subscription'**
  String get cancelSubscription_legal;

  /// No description provided for @caseTimeline2_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case Timeline2'**
  String get caseTimeline2_neutral;

  /// No description provided for @caseTimeline2_professional.
  ///
  /// In en, this message translates to:
  /// **'Case Timeline2'**
  String get caseTimeline2_professional;

  /// No description provided for @caseTimeline2_legal.
  ///
  /// In en, this message translates to:
  /// **'Case Timeline2'**
  String get caseTimeline2_legal;

  /// No description provided for @mom_neutral.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get mom_neutral;

  /// No description provided for @mom_professional.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get mom_professional;

  /// No description provided for @mom_legal.
  ///
  /// In en, this message translates to:
  /// **'Mother'**
  String get mom_legal;

  /// No description provided for @dad_neutral.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get dad_neutral;

  /// No description provided for @dad_professional.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get dad_professional;

  /// No description provided for @dad_legal.
  ///
  /// In en, this message translates to:
  /// **'Father'**
  String get dad_legal;

  /// No description provided for @guardian_neutral.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get guardian_neutral;

  /// No description provided for @guardian_professional.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get guardian_professional;

  /// No description provided for @guardian_legal.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get guardian_legal;

  /// No description provided for @expenseSubmittedSuccessfully_neutral.
  ///
  /// In en, this message translates to:
  /// **'Expense Submitted Successfully'**
  String get expenseSubmittedSuccessfully_neutral;

  /// No description provided for @expenseSubmittedSuccessfully_professional.
  ///
  /// In en, this message translates to:
  /// **'Expense Submitted Successfully'**
  String get expenseSubmittedSuccessfully_professional;

  /// No description provided for @expenseSubmittedSuccessfully_legal.
  ///
  /// In en, this message translates to:
  /// **'Expense Submitted Successfully'**
  String get expenseSubmittedSuccessfully_legal;

  /// No description provided for @submitExpense_neutral.
  ///
  /// In en, this message translates to:
  /// **'Submit Expense'**
  String get submitExpense_neutral;

  /// No description provided for @submitExpense_professional.
  ///
  /// In en, this message translates to:
  /// **'Submit Expense'**
  String get submitExpense_professional;

  /// No description provided for @submitExpense_legal.
  ///
  /// In en, this message translates to:
  /// **'Submit Expense'**
  String get submitExpense_legal;

  /// No description provided for @markAsAlreadyPaid_neutral.
  ///
  /// In en, this message translates to:
  /// **'Mark As Already Paid'**
  String get markAsAlreadyPaid_neutral;

  /// No description provided for @markAsAlreadyPaid_professional.
  ///
  /// In en, this message translates to:
  /// **'Mark As Already Paid'**
  String get markAsAlreadyPaid_professional;

  /// No description provided for @markAsAlreadyPaid_legal.
  ///
  /// In en, this message translates to:
  /// **'Mark As Already Paid'**
  String get markAsAlreadyPaid_legal;

  /// No description provided for @turnOffIfReimbursementIs_neutral.
  ///
  /// In en, this message translates to:
  /// **'Turn Off If Reimbursement Is'**
  String get turnOffIfReimbursementIs_neutral;

  /// No description provided for @turnOffIfReimbursementIs_professional.
  ///
  /// In en, this message translates to:
  /// **'Turn Off If Reimbursement Is'**
  String get turnOffIfReimbursementIs_professional;

  /// No description provided for @turnOffIfReimbursementIs_legal.
  ///
  /// In en, this message translates to:
  /// **'Turn Off If Reimbursement Is'**
  String get turnOffIfReimbursementIs_legal;

  /// No description provided for @couldNotSavePleaseTry_neutral.
  ///
  /// In en, this message translates to:
  /// **'Could Not Save Please Try'**
  String get couldNotSavePleaseTry_neutral;

  /// No description provided for @couldNotSavePleaseTry_professional.
  ///
  /// In en, this message translates to:
  /// **'Could Not Save Please Try'**
  String get couldNotSavePleaseTry_professional;

  /// No description provided for @couldNotSavePleaseTry_legal.
  ///
  /// In en, this message translates to:
  /// **'Could Not Save Please Try'**
  String get couldNotSavePleaseTry_legal;

  /// No description provided for @termsPrivacy_neutral.
  ///
  /// In en, this message translates to:
  /// **'Terms Privacy'**
  String get termsPrivacy_neutral;

  /// No description provided for @termsPrivacy_professional.
  ///
  /// In en, this message translates to:
  /// **'Terms Privacy'**
  String get termsPrivacy_professional;

  /// No description provided for @termsPrivacy_legal.
  ///
  /// In en, this message translates to:
  /// **'Terms Privacy'**
  String get termsPrivacy_legal;

  /// No description provided for @trustEvidence_neutral.
  ///
  /// In en, this message translates to:
  /// **'Trust Evidence'**
  String get trustEvidence_neutral;

  /// No description provided for @trustEvidence_professional.
  ///
  /// In en, this message translates to:
  /// **'Trust Evidence'**
  String get trustEvidence_professional;

  /// No description provided for @trustEvidence_legal.
  ///
  /// In en, this message translates to:
  /// **'Trust Evidence'**
  String get trustEvidence_legal;

  /// No description provided for @noCaseSelected_neutral.
  ///
  /// In en, this message translates to:
  /// **'No Case Selected'**
  String get noCaseSelected_neutral;

  /// No description provided for @noCaseSelected_professional.
  ///
  /// In en, this message translates to:
  /// **'No Case Selected'**
  String get noCaseSelected_professional;

  /// No description provided for @noCaseSelected_legal.
  ///
  /// In en, this message translates to:
  /// **'No Case Selected'**
  String get noCaseSelected_legal;

  /// No description provided for @upcomingExchanges_neutral.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Exchanges'**
  String get upcomingExchanges_neutral;

  /// No description provided for @upcomingExchanges_professional.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Exchanges'**
  String get upcomingExchanges_professional;

  /// No description provided for @upcomingExchanges_legal.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Exchanges'**
  String get upcomingExchanges_legal;

  /// No description provided for @scheduleNewExchange_neutral.
  ///
  /// In en, this message translates to:
  /// **'Schedule New Exchange'**
  String get scheduleNewExchange_neutral;

  /// No description provided for @scheduleNewExchange_professional.
  ///
  /// In en, this message translates to:
  /// **'Schedule New Exchange'**
  String get scheduleNewExchange_professional;

  /// No description provided for @scheduleNewExchange_legal.
  ///
  /// In en, this message translates to:
  /// **'Schedule New Exchange'**
  String get scheduleNewExchange_legal;

  /// No description provided for @schedule_neutral.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule_neutral;

  /// No description provided for @schedule_professional.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule_professional;

  /// No description provided for @schedule_legal.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule_legal;

  /// No description provided for @attorney_neutral.
  ///
  /// In en, this message translates to:
  /// **'Attorney'**
  String get attorney_neutral;

  /// No description provided for @attorney_professional.
  ///
  /// In en, this message translates to:
  /// **'Attorney'**
  String get attorney_professional;

  /// No description provided for @attorney_legal.
  ///
  /// In en, this message translates to:
  /// **'Attorney'**
  String get attorney_legal;

  /// No description provided for @judge_neutral.
  ///
  /// In en, this message translates to:
  /// **'Judge'**
  String get judge_neutral;

  /// No description provided for @judge_professional.
  ///
  /// In en, this message translates to:
  /// **'Judge'**
  String get judge_professional;

  /// No description provided for @judge_legal.
  ///
  /// In en, this message translates to:
  /// **'Judge'**
  String get judge_legal;

  /// No description provided for @notNow_neutral.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow_neutral;

  /// No description provided for @notNow_professional.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow_professional;

  /// No description provided for @notNow_legal.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow_legal;

  /// No description provided for @inviteSavedInviteLinkIs_neutral.
  ///
  /// In en, this message translates to:
  /// **'Invite Saved Invite Link Is'**
  String get inviteSavedInviteLinkIs_neutral;

  /// No description provided for @inviteSavedInviteLinkIs_professional.
  ///
  /// In en, this message translates to:
  /// **'Invite Saved Invite Link Is'**
  String get inviteSavedInviteLinkIs_professional;

  /// No description provided for @inviteSavedInviteLinkIs_legal.
  ///
  /// In en, this message translates to:
  /// **'Invite Saved Invite Link Is'**
  String get inviteSavedInviteLinkIs_legal;

  /// No description provided for @goBack_neutral.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack_neutral;

  /// No description provided for @goBack_professional.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack_professional;

  /// No description provided for @goBack_legal.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack_legal;

  /// No description provided for @balanceRefreshing_neutral.
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get balanceRefreshing_neutral;

  /// No description provided for @balanceRefreshing_professional.
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get balanceRefreshing_professional;

  /// No description provided for @balanceRefreshing_legal.
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get balanceRefreshing_legal;

  /// No description provided for @balanceUpdatedJustNow_neutral.
  ///
  /// In en, this message translates to:
  /// **'Updated just now'**
  String get balanceUpdatedJustNow_neutral;

  /// No description provided for @balanceUpdatedJustNow_professional.
  ///
  /// In en, this message translates to:
  /// **'Updated just now'**
  String get balanceUpdatedJustNow_professional;

  /// No description provided for @balanceUpdatedJustNow_legal.
  ///
  /// In en, this message translates to:
  /// **'Updated just now'**
  String get balanceUpdatedJustNow_legal;

  /// No description provided for @balanceUpdatedTodayIntro_neutral.
  ///
  /// In en, this message translates to:
  /// **'Updated today •'**
  String get balanceUpdatedTodayIntro_neutral;

  /// No description provided for @balanceUpdatedTodayIntro_professional.
  ///
  /// In en, this message translates to:
  /// **'Updated today •'**
  String get balanceUpdatedTodayIntro_professional;

  /// No description provided for @balanceUpdatedTodayIntro_legal.
  ///
  /// In en, this message translates to:
  /// **'Updated today •'**
  String get balanceUpdatedTodayIntro_legal;

  /// No description provided for @completeWorkspaceSetupToTrackBalances_neutral.
  ///
  /// In en, this message translates to:
  /// **'Complete workspace setup to track balances.'**
  String get completeWorkspaceSetupToTrackBalances_neutral;

  /// No description provided for @completeWorkspaceSetupToTrackBalances_professional.
  ///
  /// In en, this message translates to:
  /// **'Complete workspace setup to track balances.'**
  String get completeWorkspaceSetupToTrackBalances_professional;

  /// No description provided for @completeWorkspaceSetupToTrackBalances_legal.
  ///
  /// In en, this message translates to:
  /// **'Complete workspace setup to track balances.'**
  String get completeWorkspaceSetupToTrackBalances_legal;

  /// Personalized dashboard greeting
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String welcome_neutral(String name);

  /// Personalized dashboard greeting
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String welcome_professional(String name);

  /// Personalized dashboard greeting
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String welcome_legal(String name);

  /// No description provided for @balanceUpdatedMinutesAgo_neutral.
  ///
  /// In en, this message translates to:
  /// **'Updated {minutes}m ago'**
  String balanceUpdatedMinutesAgo_neutral(int minutes);

  /// No description provided for @balanceUpdatedMinutesAgo_professional.
  ///
  /// In en, this message translates to:
  /// **'Updated {minutes}m ago'**
  String balanceUpdatedMinutesAgo_professional(int minutes);

  /// No description provided for @balanceUpdatedMinutesAgo_legal.
  ///
  /// In en, this message translates to:
  /// **'Updated {minutes}m ago'**
  String balanceUpdatedMinutesAgo_legal(int minutes);

  /// No description provided for @balanceUpdatedPrefix_neutral.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get balanceUpdatedPrefix_neutral;

  /// No description provided for @balanceUpdatedPrefix_professional.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get balanceUpdatedPrefix_professional;

  /// No description provided for @balanceUpdatedPrefix_legal.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get balanceUpdatedPrefix_legal;

  /// No description provided for @navHome_neutral.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome_neutral;

  /// No description provided for @navHome_professional.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome_professional;

  /// No description provided for @navHome_legal.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome_legal;

  /// No description provided for @navInsights_neutral.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navInsights_neutral;

  /// No description provided for @navInsights_professional.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navInsights_professional;

  /// No description provided for @navInsights_legal.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navInsights_legal;

  /// No description provided for @navTimeline_neutral.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get navTimeline_neutral;

  /// No description provided for @navTimeline_professional.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get navTimeline_professional;

  /// No description provided for @navTimeline_legal.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get navTimeline_legal;

  /// No description provided for @navExchange_neutral.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get navExchange_neutral;

  /// No description provided for @navExchange_professional.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get navExchange_professional;

  /// No description provided for @navExchange_legal.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get navExchange_legal;

  /// No description provided for @navProfile_neutral.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile_neutral;

  /// No description provided for @navProfile_professional.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile_professional;

  /// No description provided for @navProfile_legal.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile_legal;

  /// No description provided for @expenseEvenPrefix_neutral.
  ///
  /// In en, this message translates to:
  /// **'Even —'**
  String get expenseEvenPrefix_neutral;

  /// No description provided for @expenseEvenPrefix_professional.
  ///
  /// In en, this message translates to:
  /// **'Even —'**
  String get expenseEvenPrefix_professional;

  /// No description provided for @expenseEvenPrefix_legal.
  ///
  /// In en, this message translates to:
  /// **'Even —'**
  String get expenseEvenPrefix_legal;

  /// No description provided for @youAreOwedPrefix_neutral.
  ///
  /// In en, this message translates to:
  /// **'You are owed '**
  String get youAreOwedPrefix_neutral;

  /// No description provided for @youAreOwedPrefix_professional.
  ///
  /// In en, this message translates to:
  /// **'You are owed '**
  String get youAreOwedPrefix_professional;

  /// No description provided for @youAreOwedPrefix_legal.
  ///
  /// In en, this message translates to:
  /// **'You are owed '**
  String get youAreOwedPrefix_legal;

  /// No description provided for @youOwePrefix_neutral.
  ///
  /// In en, this message translates to:
  /// **'You owe '**
  String get youOwePrefix_neutral;

  /// No description provided for @youOwePrefix_professional.
  ///
  /// In en, this message translates to:
  /// **'You owe '**
  String get youOwePrefix_professional;

  /// No description provided for @youOwePrefix_legal.
  ///
  /// In en, this message translates to:
  /// **'You owe '**
  String get youOwePrefix_legal;

  /// No description provided for @legalRecordStatusLoading_neutral.
  ///
  /// In en, this message translates to:
  /// **'Legal Record: …'**
  String get legalRecordStatusLoading_neutral;

  /// No description provided for @legalRecordStatusLoading_professional.
  ///
  /// In en, this message translates to:
  /// **'Record status: loading'**
  String get legalRecordStatusLoading_professional;

  /// No description provided for @legalRecordStatusLoading_legal.
  ///
  /// In en, this message translates to:
  /// **'Matter record: pending'**
  String get legalRecordStatusLoading_legal;

  /// No description provided for @dashboardTimelineInsight_neutral.
  ///
  /// In en, this message translates to:
  /// **'See timeline for documented activity.'**
  String get dashboardTimelineInsight_neutral;

  /// No description provided for @dashboardTimelineInsight_professional.
  ///
  /// In en, this message translates to:
  /// **'Review the timeline for recorded activity.'**
  String get dashboardTimelineInsight_professional;

  /// No description provided for @dashboardTimelineInsight_legal.
  ///
  /// In en, this message translates to:
  /// **'Refer to the chronological record for dated entries.'**
  String get dashboardTimelineInsight_legal;

  /// No description provided for @custodyRiskLevelStable_neutral.
  ///
  /// In en, this message translates to:
  /// **'Stable patterns'**
  String get custodyRiskLevelStable_neutral;

  /// No description provided for @custodyRiskLevelStable_professional.
  ///
  /// In en, this message translates to:
  /// **'Patterns appear stable'**
  String get custodyRiskLevelStable_professional;

  /// No description provided for @custodyRiskLevelStable_legal.
  ///
  /// In en, this message translates to:
  /// **'Documented pattern baseline: stable'**
  String get custodyRiskLevelStable_legal;

  /// No description provided for @custodyRiskLevelEmerging_neutral.
  ///
  /// In en, this message translates to:
  /// **'Emerging concerns'**
  String get custodyRiskLevelEmerging_neutral;

  /// No description provided for @custodyRiskLevelEmerging_professional.
  ///
  /// In en, this message translates to:
  /// **'Emerging risk indicators'**
  String get custodyRiskLevelEmerging_professional;

  /// No description provided for @custodyRiskLevelEmerging_legal.
  ///
  /// In en, this message translates to:
  /// **'Indicators suggest emerging exposure'**
  String get custodyRiskLevelEmerging_legal;

  /// No description provided for @custodyRiskLevelElevated_neutral.
  ///
  /// In en, this message translates to:
  /// **'Elevated conflict pattern'**
  String get custodyRiskLevelElevated_neutral;

  /// No description provided for @custodyRiskLevelElevated_professional.
  ///
  /// In en, this message translates to:
  /// **'Heightened dispute indicators'**
  String get custodyRiskLevelElevated_professional;

  /// No description provided for @custodyRiskLevelElevated_legal.
  ///
  /// In en, this message translates to:
  /// **'Elevated indicators in the documented record'**
  String get custodyRiskLevelElevated_legal;

  /// No description provided for @legalSummaryNoneYet_neutral.
  ///
  /// In en, this message translates to:
  /// **'No summary generated yet'**
  String get legalSummaryNoneYet_neutral;

  /// No description provided for @legalSummaryNoneYet_professional.
  ///
  /// In en, this message translates to:
  /// **'No summary on file yet'**
  String get legalSummaryNoneYet_professional;

  /// No description provided for @legalSummaryNoneYet_legal.
  ///
  /// In en, this message translates to:
  /// **'No generated summary in the record'**
  String get legalSummaryNoneYet_legal;

  /// No description provided for @legalSummaryLastIntro_neutral.
  ///
  /// In en, this message translates to:
  /// **'Last summary'**
  String get legalSummaryLastIntro_neutral;

  /// No description provided for @legalSummaryLastIntro_professional.
  ///
  /// In en, this message translates to:
  /// **'Most recent summary'**
  String get legalSummaryLastIntro_professional;

  /// No description provided for @legalSummaryLastIntro_legal.
  ///
  /// In en, this message translates to:
  /// **'Latest generated summary'**
  String get legalSummaryLastIntro_legal;

  /// No description provided for @trustCaseLinkageTitle_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case linkage'**
  String get trustCaseLinkageTitle_neutral;

  /// No description provided for @trustCaseLinkageTitle_professional.
  ///
  /// In en, this message translates to:
  /// **'Case linkage'**
  String get trustCaseLinkageTitle_professional;

  /// No description provided for @trustCaseLinkageTitle_legal.
  ///
  /// In en, this message translates to:
  /// **'Matter linkage'**
  String get trustCaseLinkageTitle_legal;

  /// No description provided for @trustCaseLinkageStatusConnected_neutral.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get trustCaseLinkageStatusConnected_neutral;

  /// No description provided for @trustCaseLinkageStatusConnected_professional.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get trustCaseLinkageStatusConnected_professional;

  /// No description provided for @trustCaseLinkageStatusConnected_legal.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get trustCaseLinkageStatusConnected_legal;

  /// No description provided for @trustCaseLinkageStatusNotConnected_neutral.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get trustCaseLinkageStatusNotConnected_neutral;

  /// No description provided for @trustCaseLinkageStatusNotConnected_professional.
  ///
  /// In en, this message translates to:
  /// **'Not linked'**
  String get trustCaseLinkageStatusNotConnected_professional;

  /// No description provided for @trustCaseLinkageStatusNotConnected_legal.
  ///
  /// In en, this message translates to:
  /// **'Not linked'**
  String get trustCaseLinkageStatusNotConnected_legal;

  /// No description provided for @trustCaseLinkageDetailConnected_neutral.
  ///
  /// In en, this message translates to:
  /// **'Your account is attached to an active case workspace.'**
  String get trustCaseLinkageDetailConnected_neutral;

  /// No description provided for @trustCaseLinkageDetailConnected_professional.
  ///
  /// In en, this message translates to:
  /// **'Your account is linked to an active workspace.'**
  String get trustCaseLinkageDetailConnected_professional;

  /// No description provided for @trustCaseLinkageDetailConnected_legal.
  ///
  /// In en, this message translates to:
  /// **'This account is associated with an active matter workspace.'**
  String get trustCaseLinkageDetailConnected_legal;

  /// No description provided for @trustCaseLinkageDetailNotConnected_neutral.
  ///
  /// In en, this message translates to:
  /// **'Complete setup to unlock shared records and timeline evidence.'**
  String get trustCaseLinkageDetailNotConnected_neutral;

  /// No description provided for @trustCaseLinkageDetailNotConnected_professional.
  ///
  /// In en, this message translates to:
  /// **'Finish setup to enable shared records and timeline evidence.'**
  String get trustCaseLinkageDetailNotConnected_professional;

  /// No description provided for @trustCaseLinkageDetailNotConnected_legal.
  ///
  /// In en, this message translates to:
  /// **'Complete onboarding to enable shared records and chronological evidence.'**
  String get trustCaseLinkageDetailNotConnected_legal;

  /// No description provided for @trustRecordIntegrityTitle_neutral.
  ///
  /// In en, this message translates to:
  /// **'Record integrity'**
  String get trustRecordIntegrityTitle_neutral;

  /// No description provided for @trustRecordIntegrityTitle_professional.
  ///
  /// In en, this message translates to:
  /// **'Record integrity'**
  String get trustRecordIntegrityTitle_professional;

  /// No description provided for @trustRecordIntegrityTitle_legal.
  ///
  /// In en, this message translates to:
  /// **'Record integrity'**
  String get trustRecordIntegrityTitle_legal;

  /// No description provided for @trustRecordIntegrityStatus_neutral.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get trustRecordIntegrityStatus_neutral;

  /// No description provided for @trustRecordIntegrityStatus_professional.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get trustRecordIntegrityStatus_professional;

  /// No description provided for @trustRecordIntegrityStatus_legal.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get trustRecordIntegrityStatus_legal;

  /// No description provided for @trustRecordIntegrityDetail_neutral.
  ///
  /// In en, this message translates to:
  /// **'Timeline and event records are append-only in product flows.'**
  String get trustRecordIntegrityDetail_neutral;

  /// No description provided for @trustRecordIntegrityDetail_professional.
  ///
  /// In en, this message translates to:
  /// **'Timeline entries append-only under normal product use.'**
  String get trustRecordIntegrityDetail_professional;

  /// No description provided for @trustRecordIntegrityDetail_legal.
  ///
  /// In en, this message translates to:
  /// **'Chronology entries are append-only in standard product flows.'**
  String get trustRecordIntegrityDetail_legal;

  /// No description provided for @trustParticipantsTitle_neutral.
  ///
  /// In en, this message translates to:
  /// **'Case participants'**
  String get trustParticipantsTitle_neutral;

  /// No description provided for @trustParticipantsTitle_professional.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get trustParticipantsTitle_professional;

  /// No description provided for @trustParticipantsTitle_legal.
  ///
  /// In en, this message translates to:
  /// **'Matter participants'**
  String get trustParticipantsTitle_legal;

  /// No description provided for @trustParticipantsDetail_neutral.
  ///
  /// In en, this message translates to:
  /// **'Member visibility controls who can access shared records.'**
  String get trustParticipantsDetail_neutral;

  /// No description provided for @trustParticipantsDetail_professional.
  ///
  /// In en, this message translates to:
  /// **'Membership controls access to shared records.'**
  String get trustParticipantsDetail_professional;

  /// No description provided for @trustParticipantsDetail_legal.
  ///
  /// In en, this message translates to:
  /// **'Membership governs access to shared matter records.'**
  String get trustParticipantsDetail_legal;

  /// No description provided for @trustExportReadinessTitle_neutral.
  ///
  /// In en, this message translates to:
  /// **'Export readiness'**
  String get trustExportReadinessTitle_neutral;

  /// No description provided for @trustExportReadinessTitle_professional.
  ///
  /// In en, this message translates to:
  /// **'Export readiness'**
  String get trustExportReadinessTitle_professional;

  /// No description provided for @trustExportReadinessTitle_legal.
  ///
  /// In en, this message translates to:
  /// **'Export readiness'**
  String get trustExportReadinessTitle_legal;

  /// No description provided for @trustExportReadinessStatusFull_neutral.
  ///
  /// In en, this message translates to:
  /// **'Full exports available'**
  String get trustExportReadinessStatusFull_neutral;

  /// No description provided for @trustExportReadinessStatusFull_professional.
  ///
  /// In en, this message translates to:
  /// **'Full exports enabled'**
  String get trustExportReadinessStatusFull_professional;

  /// No description provided for @trustExportReadinessStatusFull_legal.
  ///
  /// In en, this message translates to:
  /// **'Full export capability enabled'**
  String get trustExportReadinessStatusFull_legal;

  /// No description provided for @trustExportReadinessStatusLimited_neutral.
  ///
  /// In en, this message translates to:
  /// **'Limited exports'**
  String get trustExportReadinessStatusLimited_neutral;

  /// No description provided for @trustExportReadinessStatusLimited_professional.
  ///
  /// In en, this message translates to:
  /// **'Limited exports'**
  String get trustExportReadinessStatusLimited_professional;

  /// No description provided for @trustExportReadinessStatusLimited_legal.
  ///
  /// In en, this message translates to:
  /// **'Limited export capability'**
  String get trustExportReadinessStatusLimited_legal;

  /// No description provided for @trustExportReadinessDetailFull_neutral.
  ///
  /// In en, this message translates to:
  /// **'You can generate full legal export bundles from Legal Export Center.'**
  String get trustExportReadinessDetailFull_neutral;

  /// No description provided for @trustExportReadinessDetailFull_professional.
  ///
  /// In en, this message translates to:
  /// **'You may generate complete export bundles from Legal Export Center.'**
  String get trustExportReadinessDetailFull_professional;

  /// No description provided for @trustExportReadinessDetailFull_legal.
  ///
  /// In en, this message translates to:
  /// **'Full legal export bundles may be generated from Legal Export Center.'**
  String get trustExportReadinessDetailFull_legal;

  /// No description provided for @trustExportReadinessDetailLimited_neutral.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to unlock complete export bundles and court-ready reports.'**
  String get trustExportReadinessDetailLimited_neutral;

  /// No description provided for @trustExportReadinessDetailLimited_professional.
  ///
  /// In en, this message translates to:
  /// **'Upgrade for complete export bundles and court-ready reports.'**
  String get trustExportReadinessDetailLimited_professional;

  /// No description provided for @trustExportReadinessDetailLimited_legal.
  ///
  /// In en, this message translates to:
  /// **'Subscription upgrade unlocks complete export bundles and court-formatted reports.'**
  String get trustExportReadinessDetailLimited_legal;

  /// No description provided for @uxTonePreferenceTitle_neutral.
  ///
  /// In en, this message translates to:
  /// **'Writing style'**
  String get uxTonePreferenceTitle_neutral;

  /// No description provided for @uxTonePreferenceTitle_professional.
  ///
  /// In en, this message translates to:
  /// **'Copy tone'**
  String get uxTonePreferenceTitle_professional;

  /// No description provided for @uxTonePreferenceTitle_legal.
  ///
  /// In en, this message translates to:
  /// **'Terminology'**
  String get uxTonePreferenceTitle_legal;

  /// No description provided for @uxToneNeutralOption_neutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral — everyday wording'**
  String get uxToneNeutralOption_neutral;

  /// No description provided for @uxToneNeutralOption_professional.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get uxToneNeutralOption_professional;

  /// No description provided for @uxToneNeutralOption_legal.
  ///
  /// In en, this message translates to:
  /// **'Plain language tier'**
  String get uxToneNeutralOption_legal;

  /// No description provided for @uxToneProfessionalOption_neutral.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get uxToneProfessionalOption_neutral;

  /// No description provided for @uxToneProfessionalOption_professional.
  ///
  /// In en, this message translates to:
  /// **'Professional'**
  String get uxToneProfessionalOption_professional;

  /// No description provided for @uxToneProfessionalOption_legal.
  ///
  /// In en, this message translates to:
  /// **'Formal professional phrasing'**
  String get uxToneProfessionalOption_legal;

  /// No description provided for @uxToneLegalOption_neutral.
  ///
  /// In en, this message translates to:
  /// **'Legal record tone'**
  String get uxToneLegalOption_neutral;

  /// No description provided for @uxToneLegalOption_professional.
  ///
  /// In en, this message translates to:
  /// **'Matter-record tone'**
  String get uxToneLegalOption_professional;

  /// No description provided for @uxToneLegalOption_legal.
  ///
  /// In en, this message translates to:
  /// **'Court-oriented phrasing'**
  String get uxToneLegalOption_legal;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
