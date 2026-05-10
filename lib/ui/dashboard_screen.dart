import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:intl/intl.dart';
import 'package:parentledger/design/design.dart';
import 'package:parentledger/ui/case_center_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../l10n/tone_models.dart';
import '../l10n/tone_string_resolver.g.dart';
import '../providers/case_context.dart';
import '../providers/tone_preference.dart';
import '../onboarding/onboarding_steps.dart';
import '../services/case_messaging_service.dart';
import '../services/case_participant_service.dart';
import '../services/case_expense_service.dart';
import '../services/case_event_service.dart';
import '../models/case_event.dart';
import '../services/custody_risk_insights_service.dart';
import 'messages_inbox_screen.dart';
import 'conversation_thread_screen.dart';
import '../services/case_thread_catalog.dart';
import 'calendar_month_view_screen.dart';
import 'proposals_list_screen.dart';
import 'expenses_list_screen.dart';
import 'documents_library_screen.dart';
import 'compromise_dashboard_screen.dart';
import 'upcoming_exchanges_list_screen.dart';
import 'parenting_time_report_screen.dart';
import 'custody_risk_screen.dart';
import 'notifications_center_screen.dart';
import 'recent_activity_timeline_screen.dart';
import 'pending_expenses_detail_screen.dart';
import 'profile_screen.dart';
import 'exchange_checkin_screen.dart';
import 'compliance_report_screen.dart';
import 'action_inbox_screen.dart';
import 'trust_evidence_status_screen.dart';
import 'onboarding_progress_map_screen.dart';
import 'first_run_command_center_screen.dart';

import '../services/exchange_service.dart';
import '../models/exchange_model.dart';
import '../services/ai_service.dart';
import 'widgets/ai_loading_skeleton.dart';
import 'widgets/request_reimbursement_sheet.dart';
import 'widgets/subscription_trial_banner.dart';
import '../services/message_service.dart';
import '../util/exchange_maps_uri.dart';
import 'case_insights_screen.dart';
import 'route_case_guard.dart';
import 'enter_invite_code_screen.dart';
import '../services/invite_link_service.dart';
import 'timeline_violations_screen.dart';
import '../services/timeline_violation_filter.dart';
import '../services/guided_onboarding_service.dart';
import '../services/notification_service.dart';
import 'submit_expense_screen.dart';
import 'elite_case_file_hub_screen.dart';
import 'widgets/guided_step_card.dart';
import 'widgets/premium_locked_tap.dart';
import 'widgets/premium_teaser_shell.dart';
import 'widgets/premium_upgrade_sheet.dart';

class DashboardScreen extends StatefulWidget {
const DashboardScreen({super.key});

@override
State<DashboardScreen> createState() =>
_DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
with TickerProviderStateMixin {
late AnimationController pulseController;

/// Avoid duplicate [CustodyRiskInsightsService.refresh] per case.
String? _custodyRefreshedForCaseId;

/// One [NotificationService.watchUnreadCount] stream per signed-in uid — avoids creating a new
/// stream on every expense/exchange rebuild (single-subscription churn / duplicate listen).
String? _notificationUnreadStreamUid;
Stream<int>? _notificationUnreadStream;

/// Case-linked Firestore streams — one instance per active case so fast scroll / frequent rebuilds
/// do not allocate new listeners every frame ([CaseEventService.watchCaseEvents] is single-sub).
String? _dashboardCaseStreamsId;
Stream<DashboardHeaderTick>? _cachedDashboardHeaderStream;
Stream<List<CaseEvent>>? _cachedCaseEventsStream;
Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _cachedConversationsStream;
Stream<DocumentSnapshot<Map<String, dynamic>>>? _cachedRiskDocStream;
Stream<QuerySnapshot<Map<String, dynamic>>>? _cachedLegalSummaryQueryStream;

Timer? _unreadTimer;
int _unreadCount = 0;

List<QueryDocumentSnapshot<Map<String, dynamic>>> _riskEvents = [];
bool _loadingRiskEvents = true;
bool _checkingFirstRun = false;

bool _dashAiLoading = false;
bool _dashAiInFlight = false;
String? _dashAiError;
Map<String, dynamic>? _dashFairness;
String? _dashRiskLevel;
List<String> _dashIssuePreview = const [];
bool _guidedLoading = true;
bool _isFirstTimeUser = false;
bool _onboardingCompleted = false;
int _guidedMessages = 0;
int _guidedExpenses = 0;
int _guidedExchanges = 0;
bool _showOnboardingSuccess = false;
bool _openedCoparentInviteFromLink = false;

void _maybeOpenCoparentInviteFromLink() {
  if (_openedCoparentInviteFromLink) return;
  final code = InviteLinkService.pendingInviteCode.value;
  if (code == null || code.isEmpty) return;
  _openedCoparentInviteFromLink = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EnterInviteCodeScreen(initialCode: code),
        ),
      ),
    );
  });
}

@override
void initState() {
super.initState();

pulseController = AnimationController(
vsync: this,
duration: const Duration(seconds: 2),
)..repeat(reverse: true);

_unreadTimer = Timer.periodic(
const Duration(seconds: 25),
(_) => _refreshUnreadCount(),
);
WidgetsBinding.instance.addPostFrameCallback((_) {
_refreshUnreadCount();
_loadRiskEvents();
unawaited(_loadDashboardAi());
unawaited(_loadGuidedOnboardingState());
_maybeShowFirstRunExperience();
_maybeOpenCoparentInviteFromLink();
});
}

int get _guidedCompletedSteps =>
    (_guidedMessages > 0 ? 1 : 0) +
    (_guidedExpenses > 0 ? 1 : 0) +
    (_guidedExchanges > 0 ? 1 : 0);
bool get _showGuidedHome => _isFirstTimeUser && !_onboardingCompleted;
/// Parents without full access: same dashboard layout; tiles are interaction-locked only.
bool _isParentPremiumLocked() {
  final s = context.watch<CaseContext>();
  if (s.isAttorney) return false;
  return !s.unlockedParentPremiumFeatures;
}

Widget _wrapPremiumDashboardTile({
  required bool locked,
  required DashboardPremiumFeature feature,
  required Widget child,
  double shellRadius = 22,
}) {
  if (!locked) return child;
  return PremiumLockedTapHost(
    locked: true,
    onLockedTap: () => showPremiumUpgradeSheet(context, feature: feature),
    child: PremiumTeaserShell(
      locked: true,
      borderRadius: shellRadius,
      child: IgnorePointer(
        ignoring: true,
        child: child,
      ),
    ),
  );
}

Widget _insightsSection(BuildContext context) {
  final locked = _isParentPremiumLocked();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _wrapPremiumDashboardTile(
        locked: locked,
        feature: DashboardPremiumFeature.insightsCluster,
        shellRadius: 24,
        child: _buildCaseComplianceCard(context),
      ),
      const SizedBox(height: 12),
      _wrapPremiumDashboardTile(
        locked: locked,
        feature: DashboardPremiumFeature.insightsCluster,
        shellRadius: 22,
        child: _buildDashboardAiInsights(context),
      ),
      const SizedBox(height: 8),
      _wrapPremiumDashboardTile(
        locked: locked,
        feature: DashboardPremiumFeature.insightsCluster,
        shellRadius: 16,
        child: _violationsCommandTile(context),
      ),
    ],
  );
}

Future<void> _loadGuidedOnboardingState() async {
  final caseId = context.read<CaseContext>().caseId;
  if (caseId == null) {
    if (!mounted) return;
    setState(() {
      _guidedLoading = false;
      _isFirstTimeUser = false;
      _onboardingCompleted = true;
    });
    return;
  }
  try {
    final s = await GuidedOnboardingService.load(caseId);
    if (!mounted) return;
    final wasIncomplete = !_onboardingCompleted;
    setState(() {
      _guidedLoading = false;
      _isFirstTimeUser = s.isFirstTimeUser;
      _onboardingCompleted = s.onboardingCompleted;
      _guidedMessages = s.messagesCount;
      _guidedExpenses = s.expensesCount;
      _guidedExchanges = s.exchangesCount;
      _showOnboardingSuccess = wasIncomplete && s.onboardingCompleted;
    });
    if (s.onboardingCompleted) {
      await GuidedOnboardingService.markCompleted();
    }
  } catch (_) {
    if (!mounted) return;
    setState(() => _guidedLoading = false);
  }
}

Future<void> _loadDashboardAi() async {
if (!mounted) return;
if (_dashAiInFlight) return;
final caseId = context.read<CaseContext>().caseId;
if (caseId == null) return;
_dashAiInFlight = true;
setState(() {
_dashAiLoading = true;
_dashAiError = null;
});
try {
final transcript = await MessageService.buildThreadTranscript(
caseId,
CaseMessagingService.defaultConversationId,
limit: 80,
);

Map<String, dynamic>? fair;
String? proposalTextForCache;
final uid = FirebaseAuth.instance.currentUser?.uid;
if (uid != null && caseId.isNotEmpty) {
try {
final props = await FirebaseFirestore.instance
.collection('proposals')
.where('caseId', isEqualTo: caseId)
.orderBy('createdAt', descending: true)
.limit(1)
.get();
if (props.docs.isNotEmpty) {
final d = props.docs.first.data();
final parts = <String>[];
for (final k in ['title', 'summary', 'body', 'description', 'text', 'notes']) {
final v = d[k];
if (v != null && v.toString().trim().isNotEmpty) {
parts.add(v.toString());
}
}

final proposalText = parts.join('\n');
if (proposalText.length > 12) {
proposalTextForCache = proposalText;
fair = await AiService.peekFairnessCache(proposalText);
}
}
} catch (_) {
// Optional: no saved proposals or index mismatch — skip fairness tile.
}
}

var lines = transcript
.split(RegExp(r'\r?\n'))
.map((e) => e.trim())
.where((e) => e.isNotEmpty)
.toList();
if (lines.isEmpty && transcript.trim().length >= 20) {
lines = [transcript.trim()];
}

final linesForCompliance =
lines.isEmpty && transcript.trim().isNotEmpty ? <String>[transcript.trim()] : lines;

Map<String, dynamic>? compliancePeek;
if (transcript.trim().length >= 20 && linesForCompliance.isNotEmpty) {
compliancePeek = await AiService.peekComplianceCache(linesForCompliance);
}

if (mounted &&
(fair != null || compliancePeek != null)) {
setState(() {
if (fair != null) _dashFairness = fair;
if (compliancePeek != null) {
_dashRiskLevel = (compliancePeek['riskLevel'] ?? 'low').toString();
final raw = compliancePeek['issues'];
final issueList = <String>[];
if (raw is List) {
for (final e in raw) {
final s = e.toString().trim();
if (s.isNotEmpty) issueList.add(s);
}
}
_dashIssuePreview = issueList.take(3).toList();
}
});
}

Map<String, dynamic>? fairLive = fair;
if (uid != null && proposalTextForCache != null) {
try {
fairLive = await AiService.analyzeFairness(proposalTextForCache);
} catch (_) {
// Fairness optional
}
}

final compliance = transcript.trim().length < 20 || linesForCompliance.isEmpty
? <String, dynamic>{'riskLevel': 'low', 'issues': <String>[]}
: await AiService.detectComplianceIssues(linesForCompliance);

final issuesRaw = compliance['issues'];
final issueList = <String>[];
if (issuesRaw is List) {
for (final e in issuesRaw) {
final s = e.toString().trim();
if (s.isNotEmpty) issueList.add(s);
}
}

if (!mounted) return;
setState(() {
_dashAiLoading = false;
_dashFairness = fairLive ?? fair;
_dashRiskLevel = (compliance['riskLevel'] ?? 'low').toString();
_dashIssuePreview = issueList.take(3).toList();
_dashAiError = null;
});
} catch (e) {
if (!mounted) return;
final permDenied =
    e is FirebaseException && e.code == 'permission-denied';
setState(() {
_dashAiLoading = false;
if (permDenied) {
_dashAiError = null;
_dashRiskLevel ??= 'low';
_dashIssuePreview = [];
} else {
_dashAiError = AiService.userFacingMessage(e);
}
});
} finally {
_dashAiInFlight = false;
}
}

Color _dashFairnessResultColor() {
final r = (_dashFairness?['result'] ?? '').toString();
if (r == 'fair') return PLDesign.success;
if (r == 'balanced') return PLDesign.warning;
if (r == 'unfair') return PLDesign.danger;
return PLDesign.textMuted;
}

String _dashFairnessScore() {
final s = _dashFairness?['score'];
if (s is num) return s.toStringAsFixed(0);
return '—';
}

Color _dashRiskColor() {
switch (_dashRiskLevel) {
case 'high':
return PLDesign.danger;
case 'medium':
return PLDesign.warning;
default:
return PLDesign.success;
}
}

Widget _buildDashboardAiInsights(BuildContext context) {
final caseId = context.watch<CaseContext>().caseId;
if (caseId == null) return const SizedBox.shrink();

return Padding(
padding: const EdgeInsets.only(bottom: 4),
child: Material(
color: Colors.transparent,
child: InkWell(
onTap: () => Navigator.pushNamed(
  context,
  CaseRoutes.insights,
  arguments: caseId,
),
borderRadius: BorderRadius.circular(22),
child: Ink(
decoration: BoxDecoration(
gradient: const LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
Color(0xff151a26),
Color(0xff0a0e14),
],
),
borderRadius: BorderRadius.circular(22),
border: Border.all(
color: CaseInsightsScreen.accent.withValues(alpha: 0.45),
width: 1,
),
boxShadow: const [
BoxShadow(
color: Color(0x66000000),
blurRadius: 28,
offset: Offset(0, 14),
),
],
),
padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
if (_dashAiLoading) ...[
Padding(
padding: const EdgeInsets.only(bottom: 10),
child: ClipRRect(
borderRadius: BorderRadius.circular(4),
child: LinearProgressIndicator(
minHeight: 3,
backgroundColor: PLDesign.border.withValues(alpha: 0.35),
color: CaseInsightsScreen.accent,
),
),
),
Padding(
padding: const EdgeInsets.only(bottom: 8),
child: Text(
context.tTone('insightsGenerating'),
style: PLDesign.caption.copyWith(
color: PLDesign.textMuted,
fontWeight: FontWeight.w600,
height: 1.35,
),
),
),
],
Row(
children: [
Icon(Icons.auto_awesome, color: CaseInsightsScreen.accent, size: 22),
const SizedBox(width: 10),
Expanded(
child: Text(
context.tTone('insightsTitle'),
style: const TextStyle(
fontFamily: 'Georgia',
fontSize: 19,
fontWeight: FontWeight.w600,
color: Colors.white,
height: 1.2,
),
),
),
if (_dashAiLoading)
const SizedBox(width: 22, height: 22)
else
const Icon(Icons.chevron_right, color: PLDesign.textMuted, size: 22),
],
),
const SizedBox(height: 10),
if (_dashAiError != null)
Text(
_dashAiError!,
style: PLDesign.caption.copyWith(
color: PLDesign.danger,
fontWeight: FontWeight.w600,
height: 1.35,
),
)
else if (_dashAiLoading &&
_dashFairness == null &&
(_dashRiskLevel == null || _dashIssuePreview.isEmpty))
const SizedBox(
height: 96,
child: AiInsightCardSkeleton(),
)
else ...[
if (_dashFairness != null)
Row(
children: [
Container(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
decoration: BoxDecoration(
color: _dashFairnessResultColor().withValues(alpha: 0.14),
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: _dashFairnessResultColor().withValues(alpha: 0.45),
),
),
child: Text(
'Proposal: ${_dashFairness!['result']} · ${_dashFairnessScore()}',
style: TextStyle(
color: _dashFairnessResultColor(),
fontWeight: FontWeight.w800,
fontSize: 12,
),
),
),
const SizedBox(width: 8),
Expanded(
child: Text(
(_dashFairness!['reasoning'] ?? '').toString(),
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
),
),
],
)
else
Text(
'Save a proposal to see fairness scoring on your dashboard.',
style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
),
const SizedBox(height: 10),
Text(
'Compliance risk: ${_dashRiskLevel ?? '—'}',
style: PLDesign.caption.copyWith(
fontWeight: FontWeight.w800,
color: _dashRiskColor(),
),
),
const SizedBox(height: 6),
if (_dashIssuePreview.isEmpty && !_dashAiLoading && _dashAiError == null)
Text(
'No compliance issues flagged in recent messages.',
style: PLDesign.caption.copyWith(
color: PLDesign.success,
fontWeight: FontWeight.w600,
),
)
else if (_dashIssuePreview.isNotEmpty) ...[
Text(
'Quick preview',
style: PLDesign.caption.copyWith(
fontWeight: FontWeight.w700,
color: PLDesign.textMuted,
),
),
const SizedBox(height: 6),
..._dashIssuePreview.map(
(issue) => Padding(
padding: const EdgeInsets.only(bottom: 4),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('• ', style: PLDesign.caption.copyWith(color: PLDesign.warning)),
Expanded(
child: Text(
issue,
maxLines: 2,
overflow: TextOverflow.ellipsis,
style: PLDesign.caption.copyWith(height: 1.3),
),
),
],
),
),
),
Text(
'Tap for full compliance scan',
style: PLDesign.caption.copyWith(
color: PLDesign.ai,
fontWeight: FontWeight.w700,
),
),
],
],
],
),
),
),
),
);
}

Future<void> _maybeShowFirstRunExperience() async {
if (_checkingFirstRun) return;
_checkingFirstRun = true;
try {
final user = FirebaseAuth.instance.currentUser;
if (user == null || !mounted) return;
final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
final snap = await userRef.get();
final data = snap.data();
final seen = data?['firstRunCommandCenterSeenAt'] != null;
if (!seen && mounted) {
await Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const FirstRunCommandCenterScreen(),
),
);
await userRef.set(
{
'firstRunCommandCenterSeenAt': FieldValue.serverTimestamp(),
},
SetOptions(merge: true),
);
}
} catch (_) {
// Keep dashboard resilient; this helper should never block usage.
} finally {
_checkingFirstRun = false;
}
}

Future<void> _loadRiskEvents() async {
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
if (mounted) {
setState(() {
_riskEvents = [];
_loadingRiskEvents = false;
});
}
return;
}
try {
final snap = await FirebaseFirestore.instance
.collection('riskEvents')
.where('userId', isEqualTo: user.uid)
.orderBy('timestamp')
.limit(30)
.get();
if (!mounted) return;
setState(() {
_riskEvents = snap.docs;
_loadingRiskEvents = false;
});
} catch (_) {
if (mounted) {
setState(() => _loadingRiskEvents = false);
}
}
}

int _custodyRiskScore() {
var s = 20;
for (final doc in _riskEvents) {
final data = doc.data();
final type = data['type'] ?? '';
final severity = (data['severity'] ?? 1) as int;
switch (type) {
case 'missed_exchange':
s += 15 * severity;
break;
case 'late':
s += 6 * severity;
break;
case 'message_conflict':
s += 4 * severity;
break;
case 'compliance':
s -= 5 * severity;
break;
}
}
return s.clamp(0, 100).toInt();
}

String _custodyRiskLevelLabel(BuildContext context) {
  final score = _custodyRiskScore();
  if (score < 30) return context.tTone('custodyRiskLevelStable');
  if (score < 60) return context.tTone('custodyRiskLevelEmerging');
  return context.tTone('custodyRiskLevelElevated');
}

bool get _legalRecordConcern {
if (_loadingRiskEvents) return false;
final score = _custodyRiskScore();
final hasMissed = _riskEvents.any(
(e) => e.data()['type'] == 'missed_exchange',
);
return score >= 60 || hasMissed;
}

String _legalRecordStatusLine(BuildContext context) {
  if (_loadingRiskEvents) {
    return context.tTone('legalRecordStatusLoading');
  }
  return _legalRecordConcern
      ? context.tTone('legalRecordReviewRecommended')
      : context.tTone('legalRecordActive');
}

Future<void> _refreshUnreadCount() async {
final user = FirebaseAuth.instance.currentUser;
if (user == null) return;
final uid = user.uid;
try {
final userDoc = await FirebaseFirestore.instance
.collection('users')
.doc(uid)
.get();
final caseId = userDoc.data()?['caseId'] as String?;
if (caseId == null) {
if (mounted) setState(() => _unreadCount = 0);
return;
}

var total = await CaseParticipantService.getUnreadCount(caseId, uid);
if (total == 0) {
total = await CaseMessagingService.countUnread(
caseId: caseId,
conversationId: CaseMessagingService.defaultConversationId,
readerUid: uid,
scanLimit: 150,
);
}
if (mounted) setState(() => _unreadCount = total);
} catch (_) {}
}

@override
void dispose() {
_unreadTimer?.cancel();
_notificationUnreadStreamUid = null;
_notificationUnreadStream = null;
_dashboardCaseStreamsId = null;
_cachedDashboardHeaderStream = null;
_cachedCaseEventsStream = null;
_cachedConversationsStream = null;
_cachedRiskDocStream = null;
_cachedLegalSummaryQueryStream = null;
pulseController.dispose();
super.dispose();
}

void _syncNotificationUnreadStream(String? uid) {
  if (uid == _notificationUnreadStreamUid) return;
  _notificationUnreadStreamUid = uid;
  _notificationUnreadStream =
      uid == null ? null : NotificationService.watchUnreadCount(uid);
}

void _syncDashboardCaseStreams(String? caseId) {
  if (caseId == _dashboardCaseStreamsId) return;
  _dashboardCaseStreamsId = caseId;
  if (caseId == null || caseId.isEmpty) {
    _cachedDashboardHeaderStream = null;
    _cachedCaseEventsStream = null;
    _cachedConversationsStream = null;
    _cachedRiskDocStream = null;
    _cachedLegalSummaryQueryStream = null;
    return;
  }
  _cachedDashboardHeaderStream = ExchangeService.watchDashboardHeader(caseId);
  _cachedCaseEventsStream = CaseEventService.watchCaseEvents(caseId);
  _cachedConversationsStream =
      CaseMessagingService.watchConversationsSorted(caseId);
  _cachedRiskDocStream = CustodyRiskInsightsService.watchRisk(caseId);
  _cachedLegalSummaryQueryStream = FirebaseFirestore.instance
      .collection('cases')
      .doc(caseId)
      .collection('legalSummaries')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots();
}

Future<void> go(Widget screen) async {
await Navigator.push(
context,
MaterialPageRoute(builder: (_) => screen),
);
if (mounted) {
  unawaited(_loadGuidedOnboardingState());
}
}

/// [ProfileScreen] uses [CupertinoPageRoute] so iOS edge swipe-back works.
Future<void> _goProfile() async {
  await Navigator.push<void>(
    context,
    CupertinoPageRoute<void>(
      builder: (_) => const ProfileScreen(),
    ),
  );
  if (mounted) {
    unawaited(_loadGuidedOnboardingState());
  }
}

bool _isToday(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

String _balanceCardUpdatedLine(
  BuildContext context,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
  required bool loading,
}) {
  final l10n = AppLocalizations.of(context);
  final tone = context.watch<TonePreference>().tone;
  final loc = Localizations.localeOf(context).toString();
  if (loading) return toneString(l10n, 'balanceRefreshing', tone);
  if (docs.isEmpty) return toneString(l10n, 'balanceUpdatedJustNow', tone);
  Timestamp? latest;
  for (final d in docs) {
    final t = d.data()['createdAt'];
    if (t is Timestamp) {
      if (latest == null || t.compareTo(latest) > 0) latest = t;
    }
  }
  if (latest == null) return toneString(l10n, 'balanceUpdatedJustNow', tone);
  final then = latest.toDate();
  final diff = DateTime.now().difference(then);
  if (diff < const Duration(seconds: 45)) {
    return toneString(l10n, 'balanceUpdatedJustNow', tone);
  }
  if (diff < const Duration(minutes: 60)) {
    final m = diff.inMinutes.clamp(1, 59);
    return toneBalanceMinutes(l10n, m, tone);
  }
  if (_isToday(then)) {
    return '${toneString(l10n, 'balanceUpdatedTodayIntro', tone)} ${DateFormat.jm(loc).format(then)}';
  }
  return '${toneString(l10n, 'balanceUpdatedPrefix', tone)} ${DateFormat.MMMd(loc).format(then)}';
}

String _messagesUnreadSummaryLine(BuildContext context, int unread) {
  if (unread <= 0) return context.tTone('messagesUnreadNone');
  if (unread == 1) return context.tTone('messagesUnreadOne');
  return context.tMessagesUnreadCount(unread);
}

Widget _dashboardTrustBanner(BuildContext context) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          PLDesign.success.withValues(alpha: 0.28),
          PLDesign.success.withValues(alpha: 0.09),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: PLDesign.success.withValues(alpha: 0.4)),
      boxShadow: [
        BoxShadow(
          color: PLDesign.success.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tTone('dashboardTrustBannerPrimary'),
          style: PLDesign.body.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 1.3,
            color: PLDesign.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.tTone('dashboardTrustBannerSecondary'),
          style: PLDesign.caption.copyWith(
            fontSize: 13.5,
            height: 1.4,
            color: PLDesign.textMuted.withValues(alpha: 0.95),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

Widget _messagesViewAllCta(BuildContext context) {
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: () => go(const MessagesInboxScreen()),
      borderRadius: BorderRadius.circular(18),
      splashColor: Colors.white.withValues(alpha: 0.12),
      highlightColor: Colors.white.withValues(alpha: 0.06),
      child: Ink(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff4f8dff), Color(0xff2f6ce5)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3B2F6CE5),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Center(
          child: Text(
            context.tTone('viewAllThreads'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _balanceCardShell({
  required String balanceLabel,
  required Widget mainValue,
  required String updatedLine,
  String? securePillText,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          PLDesign.card,
          Color.lerp(PLDesign.card, const Color(0xff1a2a3d), 0.35) ?? PLDesign.card,
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: PLDesign.border.withValues(alpha: 0.85)),
      boxShadow: [
        ...PLDesign.softShadow,
        BoxShadow(
          color: PLDesign.primary.withValues(alpha: 0.12),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          balanceLabel,
          style: PLDesign.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: PLDesign.textMuted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        mainValue,
        const SizedBox(height: 8),
        Text(
          updatedLine,
          style: PLDesign.caption.copyWith(
            color: PLDesign.textMuted.withValues(alpha: 0.92),
            height: 1.3,
          ),
        ),
        if (securePillText != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: PLDesign.success.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: PLDesign.success.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 17,
                  color: PLDesign.success.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    securePillText,
                    style: PLDesign.caption.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: PLDesign.success.withValues(alpha: 0.95),
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

void _openAddExpense() {
  final session = context.read<CaseContext>();
  final caseId = session.caseId;
  if (caseId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tTone('linkYourCaseInWorkspace')),
      ),
    );
    return;
  }
  if (!session.isAttorney && !session.unlockedParentPremiumFeatures) {
    unawaited(
      showPremiumUpgradeSheet(
        context,
        feature: DashboardPremiumFeature.expenseLedger,
      ),
    );
    return;
  }
  go(const SubmitExpenseScreen());
}

void _openRequestReimbursement() {
  final caseId = context.read<CaseContext>().caseId;
  if (caseId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tTone('linkYourCaseInWorkspace'))),
    );
    return;
  }
  showRequestReimbursementSheet(context, caseId: caseId);
}

/// Balance card, high-priority messages, then expense actions (above the fold).
Widget _buildExpenseBalanceAndActions(BuildContext context) {
  final session = context.watch<CaseContext>();
  final caseId = session.caseId;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final user = FirebaseAuth.instance.currentUser;

  final securePill = context.tTone('balanceCardSecurePill');

  Widget messagesBlock() => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _buildMessagesHero(context, user),
      );

  Widget actionBlock(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: PLDesign.border.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 18),
          _dashboardPrimaryButton(
            label: docs.isEmpty
                ? context.tTone('addFirstExpense')
                : context.tTone('addExpense'),
            onTap: _openAddExpense,
          ),
          const SizedBox(height: 12),
          _dashboardSecondaryButton(
            label: context.tTone('requestPayment'),
            onTap: _openRequestReimbursement,
            enabled: true,
          ),
        ],
      );

  if (caseId == null || uid == null) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _balanceCardShell(
          balanceLabel: context.tTone('balance'),
          mainValue: Text(
            '—',
            style: PLDesign.heroTitle.copyWith(
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: PLDesign.textPrimary,
            ),
          ),
          updatedLine: context.tTone('completeWorkspaceSetupToTrackBalances'),
          securePillText: securePill,
        ),
        const SizedBox(height: 20),
        messagesBlock(),
        actionBlock(const []),
        const SizedBox(height: 20),
        _dashboardTrustBanner(context),
      ],
    );
  }

  // Linked case: parent wraps body with [StreamBuilder] on [CaseExpenseService.watchExpenses].
  return const SizedBox.shrink();
}

/// Balance / messages / expense CTAs from **one** expense snapshot (dashboard owns the [StreamBuilder]).
Widget _buildExpenseBalanceFromExpenseSnapshot(
  BuildContext context,
  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> expSnap,
  String uid,
  String? coparentId,
) {
  final securePill = context.tTone('balanceCardSecurePill');

  Widget messagesBlock() => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _buildMessagesHero(context, FirebaseAuth.instance.currentUser),
      );

  Widget actionBlock(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: PLDesign.border.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 18),
          _dashboardPrimaryButton(
            label: docs.isEmpty
                ? context.tTone('addFirstExpense')
                : context.tTone('addExpense'),
            onTap: _openAddExpense,
          ),
          const SizedBox(height: 12),
          _dashboardSecondaryButton(
            label: context.tTone('requestPayment'),
            onTap: _openRequestReimbursement,
            enabled: true,
          ),
        ],
      );

  final docs = expSnap.data?.docs ?? [];
  final loading = expSnap.connectionState == ConnectionState.waiting &&
      !expSnap.hasData;

  final localeTag = Localizations.localeOf(context).toString();
  final fmt = NumberFormat.simpleCurrency(locale: localeTag);
  final updatedLine = _balanceCardUpdatedLine(context, docs, loading: loading);

  late final Widget balanceCard;
  if (loading) {
    balanceCard = _balanceCardShell(
      balanceLabel: context.tTone('balance'),
      mainValue: Text(
        context.tTone('calculating'),
        style: PLDesign.heroTitle.copyWith(
          fontSize: 28,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: PLDesign.textMuted,
        ),
      ),
      updatedLine: updatedLine,
      securePillText: securePill,
    );
  } else if (docs.isEmpty) {
    balanceCard = _balanceCardShell(
      balanceLabel: context.tTone('balance'),
      mainValue: Text(
        '${context.tTone('expenseEvenPrefix')} ${fmt.format(0)}',
        style: PLDesign.heroTitle.copyWith(
          fontSize: 28,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: PLDesign.textPrimary,
        ),
      ),
      updatedLine: updatedLine,
      securePillText: securePill,
    );
  } else {
    final net = CaseExpenseService.netSplitBalanceForUser(
      uid: uid,
      coparentUid: coparentId,
      docs: docs,
    );
    final abs = net.abs();
    late final String headline;
    late final Color headColor;
    if (net > 0.009) {
      headline = '${context.tTone('youAreOwedPrefix')}${fmt.format(abs)}';
      headColor = PLDesign.success;
    } else if (net < -0.009) {
      headline = '${context.tTone('youOwePrefix')}${fmt.format(abs)}';
      headColor = PLDesign.danger;
    } else {
      headline = '${context.tTone('expenseEvenPrefix')} ${fmt.format(0)}';
      headColor = PLDesign.textPrimary;
    }
    balanceCard = _balanceCardShell(
      balanceLabel: context.tTone('balance'),
      mainValue: Text(
        headline,
        style: PLDesign.heroTitle.copyWith(
          fontSize: 28,
          height: 1.12,
          color: headColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      updatedLine: updatedLine,
      securePillText: securePill,
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      balanceCard,
      const SizedBox(height: 20),
      messagesBlock(),
      actionBlock(docs),
      const SizedBox(height: 20),
      _dashboardTrustBanner(context),
    ],
  );
}

Widget _dashboardPrimaryButton({
  required String label,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      splashColor: Colors.white.withValues(alpha: 0.14),
      highlightColor: Colors.white.withValues(alpha: 0.07),
      child: Ink(
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff5c97ff),
              Color(0xff4f8dff),
              Color(0xff2568d4),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x522F6CE5),
              blurRadius: 22,
              offset: Offset(0, 10),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Color(0x284f8dff),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _dashboardSecondaryButton({
  required String label,
  required VoidCallback onTap,
  required bool enabled,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xff0d1520),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? PLDesign.primary.withValues(alpha: 0.45)
                : PLDesign.border.withValues(alpha: 0.75),
            width: 1.1,
          ),
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: PLDesign.primary.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.attach_money_rounded,
                size: 20,
                color: enabled
                    ? PLDesign.textPrimary
                    : PLDesign.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: PLDesign.body.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? PLDesign.textPrimary : PLDesign.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _exchangeCountdownFor(ExchangeModel? nextExchange) {
if (nextExchange == null) return "No upcoming";

final diff =
nextExchange.scheduledTime.difference(DateTime.now());

if (diff.isNegative) return "In progress";

return "${diff.inHours}h ${diff.inMinutes % 60}m";
}

bool _isActiveExchangeFor(ExchangeModel? nextExchange) {
if (nextExchange == null) return false;

final diff =
nextExchange.scheduledTime.difference(DateTime.now());

return diff.inMinutes <= 15;
}

bool _hasNavigableExchangeLocation(ExchangeModel? e) {
if (e == null) return false;
if (!e.lat.isFinite || !e.lng.isFinite) return false;
if (e.lat == 0 && e.lng == 0) return false;
return true;
}

String _navigateExchangeSubtitleFor({
required bool loadingExchange,
required ExchangeModel? nextExchange,
}) {
if (loadingExchange) return 'Loading...';
final ex = nextExchange;
if (!_hasNavigableExchangeLocation(ex)) {
return 'No upcoming exchange';
}
return 'Next: ${DateFormat.jm().format(ex!.scheduledTime)}';
}

Future<void> _onNavigateToExchangeTapped(
BuildContext context, {
required ExchangeModel? nextExchange,
required bool loadingExchange,
}) async {
if (loadingExchange) return;

final ex = nextExchange;
if (!_hasNavigableExchangeLocation(ex)) {
if (!context.mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(context.tTone('noUpcomingExchangeLocationAvailable')),
),
);
return;
}

final target = ex!;

final confirmed = await showDialog<bool>(
context: context,
builder: (ctx) => AlertDialog(
title: Text(context.tTone('navigateToExchangeLocation')),
content: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
target.navigateAddress,
style: PLDesign.body,
),
const SizedBox(height: 12),
Text(
'Coordinates: ${target.lat.toStringAsFixed(6)}, ${target.lng.toStringAsFixed(6)}',
style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
),
],
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx, false),
child: Text(context.tTone('cancel')),
),
FilledButton(
onPressed: () => Navigator.pop(ctx, true),
child: Text(context.tTone('openMaps')),
),
],
),
);

if (confirmed != true || !context.mounted) return;

final uri = exchangeMapsUri(target.lat, target.lng);
try {
final ok = await canLaunchUrl(uri);
if (!ok) {
if (!context.mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(context.tTone('couldNotOpenMapsOn'))),
);
return;
}
await launchUrl(uri, mode: LaunchMode.externalApplication);
} catch (_) {
if (!context.mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(context.tTone('couldNotOpenMaps'))),
);
}
}

Widget pressable({required Widget child, required VoidCallback onTap}) {
return GestureDetector(
onTap: onTap,
child: AnimatedScale(
duration: const Duration(milliseconds: 120),
scale: 1,
child: child,
),
);
}

Widget _sectionLabel(String text) {
return Padding(
padding: const EdgeInsets.only(top: 6, bottom: 10),
child: Text(text, style: PLDesign.dashboardSectionLabel),
);
}

Widget _guidedHome(BuildContext context) {
  final done = _guidedCompletedSteps;
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 340),
    child: Column(
      key: ValueKey<int>(done),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Let's get your case set up",
          style: PLDesign.heroTitle.copyWith(fontSize: 30, height: 1.12),
        ),
        const SizedBox(height: 8),
        Text(
          "We'll walk you through everything step by step",
          style: PLDesign.caption.copyWith(color: PLDesign.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: done / 3,
            backgroundColor: PLDesign.border.withValues(alpha: 0.45),
            color: PLDesign.primary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "$done of 3 steps completed",
          style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
        ),
        const SizedBox(height: 16),
        GuidedStepCard(
          icon: Icons.forum_outlined,
          title: 'Send your first message',
          description: 'Start a court-recorded conversation',
          cta: 'Open Messages',
          completed: _guidedMessages > 0,
          onTap: () => go(const MessagesInboxScreen()),
        ),
        const SizedBox(height: 10),
        GuidedStepCard(
          icon: Icons.receipt_long_outlined,
          title: 'Add your first expense',
          description: 'Track shared costs and reimbursements',
          cta: 'Add Expense',
          completed: _guidedExpenses > 0,
          onTap: () {
            final s = context.read<CaseContext>();
            if (!s.isAttorney && !s.unlockedParentPremiumFeatures) {
              showPremiumUpgradeSheet(
                context,
                feature: DashboardPremiumFeature.expenseLedger,
              );
              return;
            }
            go(const SubmitExpenseScreen());
          },
        ),
        const SizedBox(height: 10),
        GuidedStepCard(
          icon: Icons.event_available_outlined,
          title: 'Set your schedule',
          description: 'Log or schedule custody exchanges',
          cta: 'Set Schedule',
          completed: _guidedExchanges > 0,
          onTap: () => go(const UpcomingExchangesListScreen()),
        ),
        const SizedBox(height: 18),
        Text(
          'All messages are stored as legal records.',
          style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
        ),
        const SizedBox(height: 6),
        Text(
          'Track and split costs with full history.',
          style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
        ),
        const SizedBox(height: 6),
        Text(
          'Log custody events with timestamps and location.',
          style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
        ),
      ],
    ),
  );
}

String _aiPrimaryHealthLine(String level) {
  final l = level.toLowerCase();
  if (l == 'high') return 'Needs attention right now';
  if (l == 'medium') return 'A few concerns need review';
  return 'Things look mostly okay';
}

List<Widget> _contextualNudges() {
  var unpaid = 0;
  var missed = 0;
  for (final d in _riskEvents) {
    final m = d.data();
    final type = (m['type'] ?? '').toString();
    final meta = m['metadata'];
    final metaMap = meta is Map<String, dynamic>
        ? meta
        : meta is Map
            ? Map<String, dynamic>.from(meta)
            : <String, dynamic>{};
    if (type == 'expense_added') {
      final paid = metaMap['paid'] == true || metaMap['status'] == 'paid';
      if (!paid) unpaid++;
    }
    if (type == 'exchange_missed') {
      missed++;
    }
  }
  final out = <Widget>[];
  if (unpaid > 0) {
    out.add(
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PLDesign.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PLDesign.warning.withValues(alpha: 0.35)),
        ),
        child: Text(
          '$unpaid expense${unpaid == 1 ? '' : 's'} need attention',
          style: PLDesign.caption.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
  if (missed > 0) {
    out.add(
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PLDesign.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PLDesign.info.withValues(alpha: 0.35)),
        ),
        child: Text(
          'An exchange may need review',
          style: PLDesign.caption.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
  return out;
}

/// Short relative label for conversation [updatedAt] (e.g. "2h ago").
String _relativeMessageTime(Timestamp? ts) {
  if (ts == null) return '';
  final then = ts.toDate();
  final diff = DateTime.now().difference(then);
  if (diff.isNegative || diff.inSeconds < 45) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(then);
}

Widget _buildCaseComplianceCard(BuildContext context) {
final caseId = context.watch<CaseContext>().caseId;

if (caseId == null) {
return _caseComplianceCardStatic(
context,
subtitle: _aiPrimaryHealthLine(_custodyRiskLevelLabel(context)),
insight: context.tTone('dashboardTimelineInsight'),
);
}

return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
stream: _cachedRiskDocStream!,
builder: (context, snap) {
final hasPermissionError = snap.hasError &&
    snap.error.toString().toLowerCase().contains('permission-denied');
if (hasPermissionError) {
return _caseComplianceCardStatic(
context,
subtitle: _aiPrimaryHealthLine(_custodyRiskLevelLabel(context)),
insight: context.tTone('insightsNoDataYet'),
);
}
final d = snap.data?.data();
final score = d?['riskScore'] as int?;
final level = (d?['riskLevel'] ?? '').toString();
final atRisk = (score ?? 0) >= 65 || level == 'High';
final legalColor =
atRisk ? PLDesign.warning : PLDesign.success;
final insightColor = atRisk
? PLDesign.warning.withValues(alpha: 0.95)
: PLDesign.textMuted;

final subtitle = (score != null && level.isNotEmpty)
? _aiPrimaryHealthLine(level)
: _aiPrimaryHealthLine(_custodyRiskLevelLabel(context));
final insight = context.tTone('dashboardTimelineInsight');

final factors = d?['factors'] as Map<String, dynamic>?;
final missed = (factors?['missedExchanges'] as num?)?.toInt() ?? 0;
final unpaid = (factors?['unpaidExpenses'] as num?)?.toInt() ?? 0;
final activeIssues = missed + unpaid;

final trend = (d?['riskTrend'] ?? 'stable').toString();
final prev = d?['previousRiskScore'];
String trendLine = '';
if (score != null && prev != null) {
final arrow = trend == 'up'
    ? '↑'
    : trend == 'down'
        ? '↓'
        : '→';
 trendLine = 'How things are going $arrow (prior score $prev)';
}

return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
stream: _cachedLegalSummaryQueryStream!,
builder: (context, sumSnap) {
var lastSummaryLine = context.tTone('legalSummaryNoneYet');
if (sumSnap.hasData && sumSnap.data!.docs.isNotEmpty) {
final ts =
    sumSnap.data!.docs.first.data()['createdAt'];
if (ts is Timestamp) {
lastSummaryLine =
    '${context.tTone('legalSummaryLastIntro')} · ${DateFormat.yMMMd().add_jm().format(ts.toDate())}';
}
}

return Material(
color: Colors.transparent,
child: InkWell(
onTap: () => go(const CaseCenterScreen()),
borderRadius: BorderRadius.circular(24),
child: Ink(
decoration: PLDesign.premiumCaseComplianceCard(atRisk: atRisk),
padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(
Icons.workspace_premium_rounded,
color: PLDesign.premiumGold,
size: 28,
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('Case health', style: PLDesign.premiumCaseEyebrow),
const SizedBox(height: 6),
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
child: Text('Case health', style: PLDesign.premiumCaseTitle),
),
Tooltip(
message:
    context.tTone('scoreReflectsDocumentedActivityAnd'),
triggerMode: TooltipTriggerMode.longPress,
child: Icon(
Icons.info_outline_rounded,
size: 20,
color: PLDesign.premiumChampagne.withValues(alpha: 0.55),
),
),
],
),
const SizedBox(height: 10),
Text(
subtitle,
style: PLDesign.caption.copyWith(
fontWeight: FontWeight.w600,
color: PLDesign.textMuted,
),
),
if (score != null) ...[
const SizedBox(height: 4),
Text(
  'Score: $score/100',
  style: PLDesign.caption.copyWith(color: PLDesign.textMuted, fontSize: 11),
),
],
const SizedBox(height: 10),
Text(
_legalRecordStatusLine(context),
style: PLDesign.caption.copyWith(
color: _loadingRiskEvents
? PLDesign.textMuted
: legalColor,
fontWeight: FontWeight.w700,
height: 1.35,
),
),
if (trendLine.isNotEmpty) ...[
const SizedBox(height: 10),
Text(
trendLine,
style: PLDesign.caption.copyWith(
color: PLDesign.textMuted,
fontWeight: FontWeight.w600,
),
),
],
const SizedBox(height: 10),
Text(
_documentedFlagsLine(context, activeIssues),
style: PLDesign.caption.copyWith(
fontWeight: FontWeight.w600,
color: activeIssues > 0
? PLDesign.warning.withValues(alpha: 0.95)
: PLDesign.textMuted,
),
),
const SizedBox(height: 8),
Text(
lastSummaryLine,
style: PLDesign.caption.copyWith(
color: PLDesign.info,
fontWeight: FontWeight.w600,
),
),
const SizedBox(height: 10),
Text(
insight,
style: PLDesign.body.copyWith(
fontSize: 13,
height: 1.35,
color: insightColor,
fontWeight: FontWeight.w500,
),
),
const SizedBox(height: 12),
Text(
context.tTone('scoreReflectsDocumentedActivityAnd'),
style: PLDesign.caption.copyWith(
fontSize: 10,
height: 1.3,
color: PLDesign.textMuted.withValues(alpha: 0.72),
),
),
],
),
),
Icon(
Icons.arrow_forward_ios_rounded,
color: PLDesign.premiumGold.withValues(alpha: 0.65),
size: 16,
),
],
),
],
),
),
),
);
},
);
},
);
}

String _documentedFlagsLine(BuildContext context, int total) {
  final tone = context.watch<TonePreference>().tone;
  switch (tone) {
    case UiTone.neutral:
      return 'Active issues • $total (missed exchanges + unpaid expenses)';
    case UiTone.professional:
      return 'Open items • $total (incomplete exchanges + unpaid shared expenses)';
    case UiTone.legal:
      return 'Documented open items • $total (scheduled exchange non-completion + unpaid reimbursements)';
  }
}

Widget _caseComplianceCardStatic(
BuildContext context, {
required String subtitle,
required String insight,
}) {
final atRisk = _legalRecordConcern;
final legalColor =
atRisk ? PLDesign.warning : PLDesign.success;
final insightColor = atRisk
? PLDesign.warning.withValues(alpha: 0.95)
: PLDesign.textMuted;
return Material(
color: Colors.transparent,
child: InkWell(
onTap: () => go(const CaseCenterScreen()),
borderRadius: BorderRadius.circular(24),
child: Ink(
decoration: PLDesign.premiumCaseComplianceCard(atRisk: atRisk),
padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(
Icons.workspace_premium_rounded,
color: PLDesign.premiumGold,
size: 28,
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(context.tTone('caseOverviewEyebrow'), style: PLDesign.premiumCaseEyebrow),
const SizedBox(height: 6),
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
child: Text(context.tTone('courtRecordStatusTitle'), style: PLDesign.premiumCaseTitle),
),
Tooltip(
message:
    context.tTone('scoreReflectsDocumentedActivityAnd'),
triggerMode: TooltipTriggerMode.longPress,
child: Icon(
Icons.info_outline_rounded,
size: 20,
color: PLDesign.premiumChampagne.withValues(alpha: 0.55),
),
),
],
),
const SizedBox(height: 10),
Text(
subtitle,
style: PLDesign.caption.copyWith(
fontWeight: FontWeight.w600,
color: PLDesign.textMuted,
),
),
const SizedBox(height: 10),
Text(
_legalRecordStatusLine(context),
style: PLDesign.caption.copyWith(
color: _loadingRiskEvents
? PLDesign.textMuted
: legalColor,
fontWeight: FontWeight.w700,
height: 1.35,
),
),
const SizedBox(height: 10),
Text(
insight,
style: PLDesign.body.copyWith(
fontSize: 13,
height: 1.35,
color: insightColor,
fontWeight: FontWeight.w500,
),
),
const SizedBox(height: 12),
Text(
context.tTone('scoreReflectsDocumentedActivityAnd'),
style: PLDesign.caption.copyWith(
fontSize: 10,
height: 1.3,
color: PLDesign.textMuted.withValues(alpha: 0.72),
),
),
],
),
),
Icon(
Icons.arrow_forward_ios_rounded,
color: PLDesign.premiumGold.withValues(alpha: 0.65),
size: 16,
),
],
),
],
),
),
),
);
}

/// Matches whole words only (avoids "late" inside "translate").
static final RegExp _messageUrgencyKeywords = RegExp(
r'\b(late|cancel|missed)\b',
caseSensitive: false,
);

List<TextSpan> _keywordPreviewSpans(
String text,
TextStyle base,
TextStyle highlight,
) {
final matches = _messageUrgencyKeywords.allMatches(text).toList();
if (matches.isEmpty) {
return [TextSpan(text: text, style: base)];
}
matches.sort((a, b) => a.start.compareTo(b.start));
final out = <TextSpan>[];
var i = 0;
for (final m in matches) {
if (m.start > i) {
out.add(TextSpan(text: text.substring(i, m.start), style: base));
}
out.add(TextSpan(text: text.substring(m.start, m.end), style: highlight));
i = m.end;
}
if (i < text.length) {
out.add(TextSpan(text: text.substring(i), style: base));
}
return out;
}

Widget _buildMessagesHero(BuildContext context, User? user) {
if (user == null) return const SizedBox.shrink();

final caseId = context.watch<CaseContext>().caseId;

if (caseId == null) {
final unread = _unreadCount;
final unreadLine = _messagesUnreadSummaryLine(context, unread);
final unreadStyle = unread > 0
? PLDesign.caption.copyWith(
color: PLDesign.danger,
fontWeight: FontWeight.w700,
fontSize: 13.5,
height: 1.25,
)
: PLDesign.caption.copyWith(
color: PLDesign.textMuted.withValues(alpha: 0.9),
height: 1.25,
fontSize: 13.5,
fontWeight: FontWeight.w600,
);
return Container(
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(20),
gradient: LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
PLDesign.card,
Color.lerp(PLDesign.card, PLDesign.info, 0.07) ?? PLDesign.card,
],
),
border: Border.all(
color: PLDesign.info.withValues(alpha: 0.55),
width: 1.6,
),
boxShadow: [
BoxShadow(
color: PLDesign.info.withValues(alpha: 0.22),
blurRadius: 16,
offset: const Offset(0, 8),
),
],
),
child: Material(
color: Colors.transparent,
child: InkWell(
onTap: () => go(const MessagesInboxScreen()),
borderRadius: BorderRadius.circular(20),
child: Padding(
padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Icon(
Icons.forum_rounded,
color: PLDesign.info,
size: 30,
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.center,
children: [
Expanded(
child: Text(
context.tTone('messagesCardTitle'),
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: PLDesign.sectionTitle.copyWith(
fontSize: 19,
fontWeight: FontWeight.w800,
letterSpacing: -0.3,
),
),
),
if (unread > 0) ...[
const SizedBox(width: 8),
Container(
width: 9,
height: 9,
decoration: BoxDecoration(
color: PLDesign.danger,
shape: BoxShape.circle,
boxShadow: [
BoxShadow(
color: PLDesign.danger.withValues(alpha: 0.45),
blurRadius: 6,
spreadRadius: 0,
),
],
),
),
],
],
),
const SizedBox(height: 10),
Text(
unreadLine,
style: unreadStyle,
),
],
),
),
],
),
const SizedBox(height: 18),
Text(
'Link a case to use messages',
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: PLDesign.body.copyWith(
color: PLDesign.textMuted,
height: 1.35,
fontStyle: FontStyle.italic,
fontSize: 15,
fontWeight: FontWeight.w500,
),
),
const SizedBox(height: 20),
_messagesViewAllCta(context),
],
),
),
),
),
);
}

return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
stream: _cachedConversationsStream!,
builder: (context, convSnap) {
final unread = _unreadCount;

final unreadLine = _messagesUnreadSummaryLine(context, unread);

final unreadStyle = unread > 0
? PLDesign.caption.copyWith(
color: PLDesign.danger,
fontWeight: FontWeight.w700,
fontSize: 13.5,
height: 1.25,
)
: PLDesign.caption.copyWith(
color: PLDesign.textMuted.withValues(alpha: 0.9),
height: 1.25,
fontSize: 13.5,
fontWeight: FontWeight.w600,
);

final waiting =
convSnap.connectionState == ConnectionState.waiting && !convSnap.hasData;

final byActivity = convSnap.data ?? [];
final topThread =
byActivity.isNotEmpty ? byActivity.first : null;

String? lastPreview;
if (topThread != null) {
final p =
(topThread.data()['lastMessagePreview'] ?? '').toString().trim();
if (p.isNotEmpty) lastPreview = p;
}

final noRecent = !waiting &&
(topThread == null ||
lastPreview == null ||
lastPreview.isEmpty);

final previewBase = PLDesign.body.copyWith(
color: PLDesign.textPrimary.withValues(alpha: 0.82),
height: 1.38,
fontSize: 15.5,
fontWeight: FontWeight.w600,
);
final keywordHi = previewBase.copyWith(
color: PLDesign.warning,
fontWeight: FontWeight.w800,
backgroundColor: PLDesign.warning.withValues(alpha: 0.22),
);

final hasUrgencyKeyword = lastPreview != null &&
_messageUrgencyKeywords.hasMatch(lastPreview);
final cardUrgent = unread > 0 || hasUrgencyKeyword;

final borderColor = cardUrgent
? PLDesign.warning.withValues(alpha: 0.65)
: PLDesign.info.withValues(alpha: 0.55);
final shadowColor = cardUrgent
? PLDesign.warning.withValues(alpha: 0.35)
: PLDesign.info.withValues(alpha: 0.45);

Widget previewWidget;
if (waiting) {
previewWidget = Text(
context.tTone('messagesPreviewLoading'),
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: previewBase.copyWith(
fontStyle: FontStyle.italic,
color: PLDesign.textMuted.withValues(alpha: 0.85),
),
);
} else if (noRecent) {
previewWidget = Text(
context.tTone('messagesPreviewEmpty'),
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: previewBase.copyWith(
fontStyle: FontStyle.italic,
color: PLDesign.textMuted.withValues(alpha: 0.9),
),
);
} else {
previewWidget = Text.rich(
TextSpan(
children: _keywordPreviewSpans(
lastPreview!,
previewBase,
keywordHi,
),
),
maxLines: 1,
overflow: TextOverflow.ellipsis,
);
}

void openMessagesQuick() {
if (byActivity.isNotEmpty) {
final d = byActivity.first;
final title = CaseThreadCatalog.threadTitle(d.id, d.data());
go(
ConversationThreadScreen(
title: title,
caseId: caseId,
conversationId: d.id,
),
);
} else {
go(const MessagesInboxScreen());
}
}

return Container(
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(20),
gradient: LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
PLDesign.card,
Color.lerp(
PLDesign.card,
cardUrgent ? PLDesign.warning : PLDesign.info,
0.08,
) ??
PLDesign.card,
],
),
border: Border.all(
color: borderColor,
width: cardUrgent ? 2 : 1.6,
),
boxShadow: [
BoxShadow(
color: shadowColor.withValues(alpha: cardUrgent ? 0.45 : 0.35),
blurRadius: cardUrgent ? 18 : 14,
offset: const Offset(0, 8),
),
],
),
child: Material(
color: Colors.transparent,
child: InkWell(
onTap: openMessagesQuick,
borderRadius: BorderRadius.circular(20),
child: Padding(
padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(
Icons.forum_rounded,
color: cardUrgent ? PLDesign.warning : PLDesign.info,
size: 30,
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.center,
children: [
Expanded(
child: Text(
context.tTone('messagesCardTitle'),
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: PLDesign.sectionTitle.copyWith(
fontSize: 19,
fontWeight: FontWeight.w800,
letterSpacing: -0.3,
),
),
),
if (unread > 0) ...[
const SizedBox(width: 8),
Container(
width: 9,
height: 9,
decoration: BoxDecoration(
color: PLDesign.danger,
shape: BoxShape.circle,
boxShadow: [
BoxShadow(
color: PLDesign.danger.withValues(alpha: 0.45),
blurRadius: 6,
spreadRadius: 0,
),
],
),
),
],
],
),
const SizedBox(height: 10),
Text(
unreadLine,
style: unreadStyle,
),
],
),
),
],
),
const SizedBox(height: 18),
previewWidget,
if (!waiting &&
topThread != null &&
topThread.data()['updatedAt'] is Timestamp) ...[
const SizedBox(height: 10),
Text(
_relativeMessageTime(
topThread.data()['updatedAt'] as Timestamp,
),
style: PLDesign.caption.copyWith(
fontSize: 12,
fontWeight: FontWeight.w600,
color: PLDesign.textMuted,
letterSpacing: 0.15,
),
),
],
const SizedBox(height: 20),
_messagesViewAllCta(context),
],
),
),
),
),
);
},
);
}

Widget actionCard(
IconData icon,
String title,
String sub,
Color color,
VoidCallback tap, {
bool enabled = true,
bool exchangePulseActive = false,
}) {
return Expanded(
child: IgnorePointer(
ignoring: !enabled,
child: Opacity(
opacity: enabled ? 1.0 : 0.45,
child: pressable(
onTap: tap,
child: AnimatedBuilder(
animation: pulseController,
builder: (_, child) {
final glow = exchangePulseActive
? 0.3 + (pulseController.value * 0.3)
: 0.18;

return Container(
padding: const EdgeInsets.symmetric(
vertical: 22, horizontal: 12),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [color.withOpacity(glow), PLDesign.card],
),
borderRadius: PLDesign.r20,
border: Border.all(
color: color.withOpacity(.4)),
boxShadow: [
BoxShadow(
color: color.withOpacity(glow),
blurRadius: exchangePulseActive ? 25 : 12,
)
],
),
child: Column(
children: [
Icon(icon, color: color, size: 26),
const SizedBox(height: 14),
Text(title,
textAlign: TextAlign.center,
style: PLDesign.body.copyWith(
fontWeight: FontWeight.w700,
color: Colors.white)),
const SizedBox(height: 4),
Text(sub,
textAlign: TextAlign.center,
style: PLDesign.caption),
],
),
);
},
),
),
),
),
);
}

Widget statusCard(
IconData icon,
String title,
String sub,
VoidCallback tap,
) {
return Expanded(
child: pressable(
onTap: tap,
child: Container(
padding: const EdgeInsets.symmetric(
vertical: 22, horizontal: 12),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: Column(
children: [
Icon(icon, color: PLDesign.primary, size: 26),
const SizedBox(height: 14),
Text(title,
textAlign: TextAlign.center,
style: PLDesign.body.copyWith(
fontWeight: FontWeight.w700)),
const SizedBox(height: 4),
Text(sub, style: PLDesign.caption),
],
),
),
),
);
}

Widget _onboardingProgressStrip(BuildContext context) {
final step = context.watch<CaseContext>().onboardingStep;
final done = step == OnboardingSteps.subscribed ||
step == OnboardingSteps.onboardingComplete;
return Material(
color: Colors.transparent,
child: InkWell(
onTap: () => go(const OnboardingProgressMapScreen()),
borderRadius: BorderRadius.circular(14),
child: Ink(
padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: BorderRadius.circular(14),
border: Border.all(color: PLDesign.border),
),
child: Row(
children: [
Icon(
done ? Icons.check_circle_rounded : Icons.route_rounded,
color: done ? PLDesign.success : PLDesign.primary,
size: 20,
),
const SizedBox(width: 10),
Expanded(
child: Text(
done ? 'Setup complete. View progress map' : 'Finish setup faster with progress map',
style: PLDesign.caption.copyWith(
color: PLDesign.textMuted,
fontWeight: FontWeight.w700,
),
),
),
const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
],
),
),
),
);
}

/// Premium case file entry: legal exports, live financials, activity, children.
Widget _eliteCaseFileEntry(BuildContext context) {
  final locked = _isParentPremiumLocked();
  final inner = Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => go(const EliteCaseFileHubScreen()),
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          gradient: PLDesign.premiumCaseCardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: PLDesign.premiumGold.withValues(alpha: 0.5),
            width: 1.4,
          ),
          boxShadow: PLDesign.softShadow,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.folder_special_rounded,
              color: PLDesign.premiumGold,
              size: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CASE FILE & RECORDS',
                    style: PLDesign.premiumCaseEyebrow,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Elite workspace',
                    style: PLDesign.premiumCaseTitle,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Court exports · live expenses · activity · child profiles',
                    style: PLDesign.caption.copyWith(
                      color: PLDesign.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 28),
          ],
        ),
      ),
    ),
  );
  return _wrapPremiumDashboardTile(
    locked: locked,
    feature: DashboardPremiumFeature.caseFile,
    shellRadius: 24,
    child: inner,
  );
}

/// When no case — static placeholder. Linked case uses [_pendingExpensesStatusTileFromExpenseSnapshot].
Widget _pendingExpensesStatusTileNoCase(BuildContext context) {
  return statusCard(
    Icons.attach_money,
    "Pending Expenses",
    "No case linked",
    () => go(const ExpensesListScreen()),
  );
}

/// Uses **same** expense snapshot as [_buildExpenseBalanceFromExpenseSnapshot] (dashboard owns one [StreamBuilder]).
Widget _pendingExpensesStatusTileFromExpenseSnapshot(
  BuildContext context,
  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
) {
  var sub = "Loading…";
  if (snap.hasError) {
    sub = "Unable to load";
  } else if (snap.hasData) {
    var total = 0.0;
    var count = 0;
    for (final d in snap.data!.docs) {
      final m = d.data();
      final paid = m["paid"] == true || m["status"] == "paid";
      if (!paid) {
        count++;
        final a = m["amount"];
        if (a is num) {
          total += a.toDouble();
        } else {
          total += double.tryParse("$a") ?? 0;
        }
      }
    }
    sub = count == 0
        ? "None outstanding"
        : "\$${total.toStringAsFixed(2)} · $count open";
  }
  return Expanded(
    child: pressable(
      onTap: () => go(const PendingExpensesDetailScreen()),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
        decoration: BoxDecoration(
          color: PLDesign.card,
          borderRadius: PLDesign.r20,
          border: Border.all(color: PLDesign.border),
          boxShadow: PLDesign.softShadow,
        ),
        child: Column(
          children: [
            Icon(Icons.attach_money, color: PLDesign.primary, size: 26),
            const SizedBox(height: 14),
            Text(
              "Pending Expenses",
              textAlign: TextAlign.center,
              style: PLDesign.body.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(sub, style: PLDesign.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

Widget _violationsCommandTile(BuildContext context) {
final caseId = context.watch<CaseContext>().caseId;
if (caseId == null) return const SizedBox.shrink();

return StreamBuilder<List<CaseEvent>>(
stream: _cachedCaseEventsStream!,
builder: (context, snap) {
var n = 0;
if (snap.hasData) {
for (final e in snap.data!) {
if (TimelineViolationFilter.caseEventIsViolation(e)) n++;
}
}
final urgent = n > 0;
final borderColor = urgent
? PLDesign.warning.withValues(alpha: 0.55)
: PLDesign.border;
return Padding(
padding: const EdgeInsets.only(top: 2),
child: Material(
color: Colors.transparent,
child: InkWell(
onTap: () => Navigator.pushNamed(
  context,
  CaseRoutes.violations,
  arguments: caseId,
),
borderRadius: BorderRadius.circular(16),
child: Ink(
decoration: BoxDecoration(
color: const Color(0xff0f141c),
borderRadius: BorderRadius.circular(16),
border: Border.all(color: borderColor, width: urgent ? 1.35 : 1),
),
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
child: Row(
children: [
Icon(
Icons.gavel_rounded,
color: urgent ? PLDesign.warning : TimelineViolationsScreen.accent,
size: 22,
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
"Issues to review",
style: PLDesign.body.copyWith(
fontWeight: FontWeight.w700,
fontSize: 15,
),
),
const SizedBox(height: 2),
Text(
n == 0
? "None on record · opens timeline violations"
: "$n item${n == 1 ? "" : "s"} on record · tap for detail",
style: PLDesign.caption.copyWith(
color: urgent ? PLDesign.warning : PLDesign.textMuted,
fontWeight: FontWeight.w600,
height: 1.25,
),
),
],
),
),
Icon(
Icons.arrow_forward_ios_rounded,
color: PLDesign.premiumGold.withValues(alpha: 0.5),
size: 14,
),
],
),
),
),
),
);
},
);
}

Widget _dashboardTool(
  IconData icon,
  String label,
  VoidCallback tap, {
  bool premiumTool = false,
  bool calendarLimited = false,
  DashboardPremiumFeature premiumFeature = DashboardPremiumFeature.complianceReports,
}) {
  final parentLocked = _isParentPremiumLocked();
  final locked = premiumTool && parentLocked;
  final limitedCalendar = calendarLimited && parentLocked;

  final inner = Container(
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xff0c1018),
      borderRadius: PLDesign.r20,
      border: Border.all(
        color: PLDesign.premiumGold.withValues(alpha: 0.08),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x42000000),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: PLDesign.premiumGold.withValues(alpha: 0.85), size: 26),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: PLDesign.body.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            height: 1.2,
          ),
        ),
      ],
    ),
  );

  if (limitedCalendar) {
    return pressable(
      onTap: tap,
      child: ClipRRect(
        borderRadius: PLDesign.r20,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            inner,
            const LimitedCornerBadge(),
          ],
        ),
      ),
    );
  }

  if (locked) {
    return PremiumLockedTapHost(
      locked: true,
      onLockedTap: () => showPremiumUpgradeSheet(context, feature: premiumFeature),
      child: PremiumTeaserShell(
        locked: true,
        borderRadius: 20,
        child: inner,
      ),
    );
  }

  return pressable(onTap: tap, child: inner);
}

@override
Widget build(BuildContext context) {
/// Fixed 3 columns → 3×3 grid for nine tools (balanced; avoids orphan tile on wide phones).
const toolCrossCount = 3;

final uid = FirebaseAuth.instance.currentUser?.uid;
_syncNotificationUnreadStream(uid);
final caseId = context.watch<CaseContext>().caseId;
final coparentId = context.watch<CaseContext>().coparentId;
_syncDashboardCaseStreams(caseId);

if (caseId == null || uid == null) {
return _dashboardScaffold(
context,
toolCrossCount: toolCrossCount,
uid: uid,
caseId: caseId,
coparentId: coparentId,
nextExchange: null,
loadingExchange: false,
expenseSnapshot: null,
exchangePulseActive: false,
);
}

return StreamBuilder<DashboardHeaderTick>(
stream: _cachedDashboardHeaderStream!,
builder: (context, headerSnap) {
if (_custodyRefreshedForCaseId != caseId) {
_custodyRefreshedForCaseId = caseId;
WidgetsBinding.instance.addPostFrameCallback((_) {
unawaited(CustodyRiskInsightsService.refresh(caseId));
});
}

final waitingHeader =
headerSnap.connectionState == ConnectionState.waiting && !headerSnap.hasData;
if (headerSnap.hasError) {
return _dashboardScaffold(
context,
toolCrossCount: toolCrossCount,
uid: uid,
caseId: caseId,
coparentId: coparentId,
nextExchange: null,
loadingExchange: false,
expenseSnapshot: AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>.withError(
ConnectionState.done,
headerSnap.error!,
headerSnap.stackTrace ?? StackTrace.empty,
),
exchangePulseActive: false,
);
}
if (waitingHeader || !headerSnap.hasData) {
return _dashboardScaffold(
context,
toolCrossCount: toolCrossCount,
uid: uid,
caseId: caseId,
coparentId: coparentId,
nextExchange: null,
loadingExchange: true,
expenseSnapshot: null,
exchangePulseActive: false,
);
}

final tick = headerSnap.data!;
final expSnap = AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>.withData(
ConnectionState.active,
tick.expenses,
);
return _dashboardScaffold(
context,
toolCrossCount: toolCrossCount,
uid: uid,
caseId: caseId,
coparentId: coparentId,
nextExchange: tick.nextExchange,
loadingExchange: tick.exchangeLoading,
expenseSnapshot: expSnap,
exchangePulseActive: _isActiveExchangeFor(tick.nextExchange),
);
},
);
}

Widget _dashboardScaffold(
BuildContext context, {
required int toolCrossCount,
required String? uid,
required String? caseId,
required String? coparentId,
required ExchangeModel? nextExchange,
required bool loadingExchange,
required AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>? expenseSnapshot,
required bool exchangePulseActive,
}) {
return Scaffold(
backgroundColor: PLDesign.background,
body: Stack(
children: [
Positioned.fill(
child: DecoratedBox(
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: const Alignment(0, 0.38),
colors: [
const Color(0xff141d2e),
PLDesign.background,
],
stops: const [0.0, 1.0],
),
),
),
),
SafeArea(
child: ListView(
padding: const EdgeInsets.fromLTRB(22, 20, 22, 100),
children: [
Stack(
clipBehavior: Clip.none,
children: [
Positioned(
left: -56,
top: -40,
child: IgnorePointer(
child: Container(
width: 220,
height: 180,
decoration: BoxDecoration(
shape: BoxShape.circle,
gradient: RadialGradient(
colors: [
const Color(0x334f8dff),
const Color(0x084f8dff),
Colors.transparent,
],
stops: const [0.0, 0.45, 1.0],
),
),
),
),
),
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
context.tTone('dashboardPremiumHeadline'),
style: PLDesign.heroTitle.copyWith(
fontSize: 24,
height: 1.15,
fontWeight: FontWeight.w800,
letterSpacing: -0.45,
),
),
const SizedBox(height: 8),
Text(
context.tTone('dashboardPremiumTagline'),
style: PLDesign.caption.copyWith(
color: PLDesign.textMuted.withValues(alpha: 0.88),
fontSize: 14.5,
height: 1.4,
fontWeight: FontWeight.w500,
),
),
],
),
),
Row(
mainAxisSize: MainAxisSize.min,
children: [
IconButton(
onPressed: () => go(const NotificationsCenterScreen()),
icon: StreamBuilder<int>(
  stream: _notificationUnreadStream,
  builder: (context, snap) {
    final unread = snap.data ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_outlined),
        if (unread > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  },
),
color: PLDesign.textPrimary,
),
const SizedBox(width: 2),
IconButton(
onPressed: () => go(const MessagesInboxScreen()),
icon: const Icon(Icons.chat_bubble_outline_rounded),
color: PLDesign.textPrimary,
tooltip: context.tTone('messagesCardTitle'),
),
],
),
],
),
],
),

const SizedBox(height: 22),

expenseSnapshot == null
? _buildExpenseBalanceAndActions(context)
: _buildExpenseBalanceFromExpenseSnapshot(
context,
expenseSnapshot,
uid!,
coparentId,
),

const SizedBox(height: 28),
..._contextualNudges(),
if (_guidedLoading)
const Padding(
  padding: EdgeInsets.only(bottom: 16),
  child: Center(
    child: SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  ),
),
if (!_guidedLoading && _showGuidedHome) ...[
_guidedHome(context),
const SizedBox(height: 20),
],
if (_showOnboardingSuccess)
Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: PLDesign.success.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: PLDesign.success.withValues(alpha: 0.35)),
  ),
  child: Text(
    "You're all set. Your case is now being tracked.",
    style: PLDesign.body.copyWith(fontWeight: FontWeight.w600),
  ),
),
Text(
context.tTone('caseOverview'),
style: PLDesign.dashboardHeroSubtitle,
),

const SizedBox(height: 14),
_onboardingProgressStrip(context),
const SizedBox(height: 8),
const SubscriptionTrialBanner(),
const SizedBox(height: 12),
_eliteCaseFileEntry(context),
const SizedBox(height: 4),

_sectionLabel('INSIGHTS'),
_insightsSection(context),
const SizedBox(height: 18),
_sectionLabel('SCHEDULE'),
Row(children: [
actionCard(
Icons.gps_fixed,
"Exchange Check-In",
loadingExchange
? "Loading..."
: nextExchange == null
? "You're all caught up - schedule your next exchange"
: "Verify arrival",
PLDesign.success,
() {
if (loadingExchange || caseId == null) return;
go(ExchangeCheckinScreen(
caseId: caseId,
scheduledExchange: nextExchange,
));
},
exchangePulseActive: exchangePulseActive,
),
const SizedBox(width: 12),
actionCard(
Icons.map,
"Navigate",
_navigateExchangeSubtitleFor(
loadingExchange: loadingExchange,
nextExchange: nextExchange,
),
PLDesign.info,
() => _onNavigateToExchangeTapped(
context,
nextExchange: nextExchange,
loadingExchange: loadingExchange,
),
enabled: !loadingExchange &&
_hasNavigableExchangeLocation(nextExchange),
exchangePulseActive: exchangePulseActive,
),
]),
const SizedBox(height: 12),
Row(children: [
statusCard(Icons.calendar_today, "Upcoming",
_exchangeCountdownFor(nextExchange),
() {
if (nextExchange == null) {
go(const UpcomingExchangesListScreen());
return;
}
if (_isActiveExchangeFor(nextExchange) && caseId != null) {
go(ExchangeCheckinScreen(
caseId: caseId,
scheduledExchange: nextExchange,
));
} else {
go(const UpcomingExchangesListScreen());
}
},
),
const SizedBox(width: 12),
expenseSnapshot == null
? _pendingExpensesStatusTileNoCase(context)
: _pendingExpensesStatusTileFromExpenseSnapshot(context, expenseSnapshot),
]),
const SizedBox(height: 8),
_sectionLabel('TOOLS'),
GridView.count(
crossAxisCount: toolCrossCount,
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
mainAxisSpacing: 14,
crossAxisSpacing: 14,
childAspectRatio: 1.02,
children: [
_dashboardTool(
    Icons.calendar_month,
    "Calendar",
    () => go(const CalendarMonthViewScreen()),
    calendarLimited: true,
),
_dashboardTool(
    Icons.handshake,
    "Proposals",
    () => go(const ProposalsListScreen()),
    premiumTool: true,
    premiumFeature: DashboardPremiumFeature.proposals,
),
_dashboardTool(
    Icons.attach_money,
    "Expenses",
    () => go(const ExpensesListScreen()),
    premiumTool: true,
    premiumFeature: DashboardPremiumFeature.expenseLedger,
),
_dashboardTool(
    Icons.folder_outlined,
    "Documents",
    () => go(const DocumentsLibraryScreen()),
    premiumTool: true,
    premiumFeature: DashboardPremiumFeature.documentsLibrary,
),
_dashboardTool(
  Icons.family_restroom_outlined,
  "Parenting",
  () => go(const ParentingTimeReportScreen()),
  premiumTool: true,
  premiumFeature: DashboardPremiumFeature.parentingReport,
),
_dashboardTool(
    Icons.scale,
    "Compromise",
    () => go(const CompromiseDashboardScreen()),
    premiumTool: true,
    premiumFeature: DashboardPremiumFeature.compromiseBoard,
),
_dashboardTool(Icons.checklist_rounded, "Action Inbox",
    () => go(const ActionInboxScreen())),
_dashboardTool(
  Icons.verified_user_outlined,
  "Trust",
  () => go(const TrustEvidenceStatusScreen()),
),
_dashboardTool(
  Icons.bar_chart,
  "Reports",
  () => go(const ComplianceReportScreen()),
  premiumTool: true,
  premiumFeature: DashboardPremiumFeature.complianceReports,
),
],
),

const SizedBox(height: 28),
],
),
),
],

),

bottomNavigationBar: BottomNavigationBar(
currentIndex: 0,
selectedItemColor: PLDesign.primary,
backgroundColor: PLDesign.surface,
type: BottomNavigationBarType.fixed,
onTap: (i) {
if (i == 1) go(const CustodyRiskScreen());
if (i == 2) go(const RecentActivityTimelineScreen());
if (i == 3) go(const UpcomingExchangesListScreen());
if (i == 4) _goProfile();
},
items: [
BottomNavigationBarItem(icon: const Icon(Icons.home), label: context.tTone('navHome')),
BottomNavigationBarItem(icon: const Icon(Icons.psychology), label: context.tTone('navInsights')),
BottomNavigationBarItem(icon: const Icon(Icons.timeline), label: context.tTone('navTimeline')),
BottomNavigationBarItem(icon: const Icon(Icons.location_pin), label: context.tTone('navExchange')),
BottomNavigationBarItem(icon: const Icon(Icons.person), label: context.tTone('navProfile')),
],
),
);
}
}