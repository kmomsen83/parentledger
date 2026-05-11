import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/design.dart';
import '../design/pl_premium_components.dart';
import '../repositories/invite_repository.dart';
import '../services/coparent_invite_code_service.dart';
import '../services/firestore_fields.dart';
import 'invite_phone_sheet.dart';

/// Where the co-parent invite sheet was opened from (copy + bottom actions).
enum CoparentInviteSheetMode {
  /// Profile / tools — primary action closes and returns to the app.
  hub,
  /// Guided setup — emphasizes activation and optional skip.
  onboarding,
}

Future<void> showCoparentInviteSheet(
  BuildContext context, {
  CoparentInviteSheetMode mode = CoparentInviteSheetMode.hub,
  int activationStep = 4,
  int activationTotal = 6,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (ctx) => _CoparentInviteSheet(
      mode: mode,
      activationStep: activationStep,
      activationTotal: activationTotal,
    ),
  );
}

class _CoparentInviteSheet extends StatefulWidget {
  const _CoparentInviteSheet({
    required this.mode,
    required this.activationStep,
    required this.activationTotal,
  });

  final CoparentInviteSheetMode mode;
  final int activationStep;
  final int activationTotal;

  @override
  State<_CoparentInviteSheet> createState() => _CoparentInviteSheetState();
}

class _CoparentInviteSheetState extends State<_CoparentInviteSheet>
    with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  CoparentInviteLinkResult? _result;
  String? _caseId;
  Timer? _countdownTimer;
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _create();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await InviteRepository.createCoParentInvite();
      final r = CoparentInviteLinkResult(
        token: snap.code,
        universalLink: snap.universalLink,
        deepLink: snap.deepLink,
        expiresAtIso: snap.expiresAt?.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
      unawaited(_loadCaseIdForWatch());
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    } catch (e, st) {
      if (!mounted) return;
      final raw = e.toString();
      final friendly = raw.startsWith('Exception: ')
          ? raw.replaceFirst('Exception: ', '')
          : raw.replaceFirst(RegExp(r'^StateError:\s*'), '');
      assert(() {
        debugPrint('Coparent invite create failed: $e\n$st');
        return true;
      }());
      setState(() {
        _error = friendly;
        _loading = false;
      });
    }
  }

  Future<void> _loadCaseIdForWatch() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      final cid = doc.data()?['caseId'] as String?;
      if (mounted && cid != null && cid.isNotEmpty) {
        setState(() => _caseId = cid);
      }
    } catch (_) {}
  }

  String _expiryLabel() {
    final iso = _result?.expiresAtIso;
    if (iso == null) return 'Expires in 48 hours';
    final t = DateTime.tryParse(iso);
    if (t == null) return 'Expires in 48 hours';
    final d = t.difference(DateTime.now());
    if (d.isNegative) return 'This invite has expired';
    if (d.inDays >= 1) return 'Expires in ${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return 'Expires in ${d.inHours}h ${d.inMinutes % 60}m';
    return 'Expires in ${d.inMinutes.clamp(1, 9999)}m';
  }

  Future<String> _inviterShortNameResolved() async {
    final u = FirebaseAuth.instance.currentUser;
    final d = u?.displayName?.trim();
    if (d != null && d.isNotEmpty) {
      return d.split(RegExp(r'\s+')).first;
    }
    if (u == null) return 'A parent';
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      final fn = doc.data()?['firstName']?.toString().trim() ?? '';
      if (fn.isNotEmpty) return fn;
    } catch (_) {}
    return 'A parent';
  }

  Future<void> _share() async {
    final r = _result;
    if (r == null || r.token.isEmpty || r.universalLink.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invite link is not ready yet. Try again in a moment.',
          ),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    final name = await _inviterShortNameResolved();
    final body = CoparentInviteCodeService.shareMessageForInviter(
      inviterFirstName: name,
      invite: r,
    );
    await Share.share(body);
    if (mounted) setState(() {});
  }

  Future<void> _copyLink() async {
    final r = _result;
    if (r == null || r.universalLink.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invite link to copy yet.')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: r.universalLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Secure link copied')),
    );
  }

  Future<void> _shareEmail() async {
    final r = _result;
    if (r == null || r.universalLink.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invite link yet.')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    final name = await _inviterShortNameResolved();
    final body = CoparentInviteCodeService.shareMessageForInviter(
      inviterFirstName: name,
      invite: r,
    );
    final subject = Uri.encodeComponent('ParentLedger co-parent invite');
    final bodyEnc = Uri.encodeComponent(body);
    final uri = Uri.parse('mailto:?subject=$subject&body=$bodyEnc');
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email app found — use Copy link or Share.'),
        ),
      );
    }
  }

  void _pop() {
    HapticFeedback.lightImpact();
    Navigator.of(context).maybePop();
  }

  Widget _trustChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: const [
        _TrustMini(
          icon: Icons.lock_outline_rounded,
          label: 'Encrypted in transit',
        ),
        _TrustMini(
          icon: Icons.gavel_rounded,
          label: 'Court-ready records',
        ),
        _TrustMini(
          icon: Icons.link_off_outlined,
          label: 'One-time secure link',
        ),
      ],
    );
  }

  Widget _headerWithGlow() {
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (context, child) {
        final v = 0.45 + 0.25 * (1 + (0.5 - (_glowCtrl.value - 0.5).abs() * 2));
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -40,
              right: -40,
              top: -28,
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.1,
                    colors: [
                      PLDesign.primary.withValues(alpha: 0.12 * v),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: PLSectionHeader(
        title: 'Invite Your Co-Parent',
        subtitle:
            'Securely connect accounts to share schedules, expenses, messages, '
            'and court-ready records.',
      ),
    );
  }

  List<PLInviteStatusStep> _inviteFlowSteps(bool connected) {
    return [
      const PLInviteStatusStep(
        title: 'Secure invite created',
        subtitle: 'Private link is tied to your case',
        state: PLInviteStepState.complete,
      ),
      PLInviteStatusStep(
        title: 'Invite ready',
        subtitle: _expiryLabel(),
        state: PLInviteStepState.complete,
      ),
      PLInviteStatusStep(
        title: 'Waiting for your co-parent',
        subtitle: 'They tap once — ParentLedger opens on their device',
        state: connected ? PLInviteStepState.complete : PLInviteStepState.active,
      ),
      PLInviteStatusStep(
        title: 'Co-parent connected',
        subtitle: connected
            ? 'Schedules, messages, and records stay in sync'
            : 'You will see a confirmation here when they join',
        state: connected ? PLInviteStepState.complete : PLInviteStepState.pending,
      ),
    ];
  }

  Widget _inviteGlassCard({required bool connected}) {
    return PLGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PLDesign.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: PLDesign.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: PLDesign.primary.withValues(alpha: 0.95),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'Workspace linked' : 'Secure invite',
                      style: PLDesign.sectionTitle.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'One tap opens ParentLedger on their phone. Link is single-use and time-limited.',
                      style: PLDesign.onboardingSupporting.copyWith(fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PLStatusBadge(
                label: _expiryLabel(),
                icon: Icons.schedule_rounded,
                accent: PLDesign.warning,
              ),
              const PLStatusBadge(
                label: 'One-time link',
                icon: Icons.link_rounded,
                accent: PLDesign.info,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Share using',
            style: PLDesign.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.45),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Messages · Email · Copy link · Any app they prefer',
            style: PLDesign.onboardingSupporting.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 18),
          PLInviteStatus(steps: _inviteFlowSteps(connected)),
          const SizedBox(height: 8),
          if (_result != null && !_loading) ...[
            PLPrimaryButton(
              label: context.tTone('sendInvite_neutral'),
              icon: Icons.ios_share_rounded,
              onPressed: _share,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.9),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareEmail,
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Email'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.9),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 420.ms, curve: Curves.easeOutCubic).slideY(
          begin: 0.04,
          end: 0,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _stickyBottom(double kb, {required bool connected}) {
    final isOnboarding = widget.mode == CoparentInviteSheetMode.onboarding;
    final primaryLabel = isOnboarding
        ? 'Continue setup'
        : 'Continue to dashboard';
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PLDesign.card.withValues(alpha: 0.0),
              PLDesign.card,
              PLDesign.card,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: PLDesign.primary.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + kb),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isOnboarding) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: widget.activationStep / widget.activationTotal,
                              minHeight: 4,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.08),
                              color: PLDesign.primary.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Step ${widget.activationStep} of ${widget.activationTotal}',
                          style: PLDesign.onboardingTrustChip.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  PLPrimaryButton(
                    label: primaryLabel,
                    onPressed: _pop,
                  ),
                  if (isOnboarding) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).maybePop();
                      },
                      child: Text(
                        'Skip and finish later',
                        style: PLDesign.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                  if (!isOnboarding) const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showInvitePhoneSheet(context, role: 'coparent');
                    },
                    child: Text(
                      'Invite by phone instead',
                      style: PLDesign.caption.copyWith(
                        color: PLDesign.primary.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (connected)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: PLDesign.success.withValues(alpha: 0.95),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Co-parent is on this case',
                            style: PLDesign.caption.copyWith(
                              color: PLDesign.success.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 350.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    final maxH = mq.size.height * 0.94;

    Widget bodyCore(bool connected) {
      final contentW = math.min(520.0, mq.size.width - 36);
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentW),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _headerWithGlow(),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _trustChips(),
          ),
          const SizedBox(height: 22),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: PLLoadingState(
                message: 'Creating a secure, one-time link for your co-parent…',
                minHeight: 140,
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: PLEmptyState(
                title: 'We could not create the invite',
                body: _error!,
                icon: Icons.shield_outlined,
                actionLabel: 'Try again',
                onAction: _create,
              ),
            )
          else if (_result != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _inviteGlassCard(connected: connected),
            ),
          const SizedBox(height: 24),
        ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: mq.padding.top > 20 ? 8 : 0),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxH),
            decoration: BoxDecoration(
              color: PLDesign.card,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 40,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: _caseId != null && _result != null && !_loading
                ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('cases')
                        .doc(_caseId)
                        .snapshots(),
                    builder: (context, snap) {
                      final data = snap.data?.data();
                      final ids = data != null
                          ? FirestoreFields.readCaseMemberIds(data)
                          : <String>[];
                      final connected = ids.length >= 2;
                      return Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.only(bottom: 8 + kb * 0.25),
                              child: bodyCore(connected),
                            ),
                          ),
                          _stickyBottom(kb, connected: connected),
                        ],
                      );
                    },
                  )
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(bottom: 8 + kb * 0.25),
                          child: bodyCore(false),
                        ),
                      ),
                      _stickyBottom(kb, connected: false),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _TrustMini extends StatelessWidget {
  const _TrustMini({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: PLDesign.info.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Text(label, style: PLDesign.onboardingTrustChip),
        ],
      ),
    );
  }
}
