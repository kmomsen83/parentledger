import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:share_plus/share_plus.dart';

import '../design/design.dart';
import '../onboarding/onboarding_steps.dart';
import '../services/coparent_invite_code_service.dart';
import 'invite_phone_sheet.dart';

/// Co-parent connection: secure UUID token + Universal Link / native scheme (no Safari round-trip).
class WorkspaceCoparentSetupScreen extends StatefulWidget {
  const WorkspaceCoparentSetupScreen({super.key});

  @override
  State<WorkspaceCoparentSetupScreen> createState() =>
      _WorkspaceCoparentSetupScreenState();
}

class _WorkspaceCoparentSetupScreenState
    extends State<WorkspaceCoparentSetupScreen> {
  bool _loading = true;
  bool _advancing = false;
  String? _error;
  CoparentInviteLinkResult? _invite;

  @override
  void initState() {
    super.initState();
    _createInvite();
  }

  Future<void> _createInvite() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await CoparentInviteCodeService.createInviteCode();
      if (!mounted) return;
      setState(() {
        _invite = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _inviterShortNameSync() {
    final u = FirebaseAuth.instance.currentUser;
    final d = u?.displayName?.trim();
    if (d != null && d.isNotEmpty) {
      return d.split(RegExp(r'\s+')).first;
    }
    return '';
  }

  Future<String> _inviterShortNameResolved() async {
    final sync = _inviterShortNameSync();
    if (sync.isNotEmpty) return sync;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'A parent';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final fn =
          doc.data()?['firstName']?.toString().trim() ?? '';
      if (fn.isNotEmpty) return fn;
    } catch (_) {}
    return 'A parent';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _shareInvite() async {
    final r = _invite;
    if (r == null ||
        r.token.isEmpty ||
        r.universalLink.isEmpty) {
      _snack('Invite link is not ready yet.');
      return;
    }
    final name = await _inviterShortNameResolved();
    final body = CoparentInviteCodeService.shareMessageForInviter(
      inviterFirstName: name,
      invite: r,
    );
    await SharePlus.instance.share(
      ShareParams(text: body),
    );
  }

  Future<void> _continueOnboarding() async {
    if (_advancing) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _advancing = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'onboardingStep': OnboardingSteps.coparentInvited,
      });
      if (!mounted) return;
      _snack(context.tTone('inviteSavedInviteLinkIs'));
    } catch (_) {
      if (mounted) _snack('Could not save progress');
    }
    if (mounted) setState(() => _advancing = false);
  }

  Future<void> skip() async {
    if (_advancing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: const Text(
          'Skip for now?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You can invite your co-parent anytime from Profile → Invite Co-Parent.',
          style: TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tTone('goBack')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tTone('skip')),
          ),
        ],
      ),
    );

    if (go != true) return;

    setState(() => _advancing = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'onboardingStep': OnboardingSteps.coparentInvited,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You can invite later from Profile → Invite Co-Parent.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) _snack('Failed to continue');
    }

    if (mounted) setState(() => _advancing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: PLDesign.screenGradient),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  const Text(
                    'Invite Co-Parent',
                    style: PLDesign.pageTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Send a secure link. ParentLedger opens directly — no copying codes '
                    '(legacy codes remain available under “Enter code”).',
                    style: PLDesign.body.copyWith(height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (_loading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error!,
                            style: PLDesign.body.copyWith(color: PLDesign.danger),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _createInvite,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  else if (_invite != null) ...[
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: PLDesign.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: PLDesign.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.verified_user_rounded,
                                        color: PLDesign.primary,
                                        size: 26,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Secure invite · 48h · one-time use',
                                          style: PLDesign.caption.copyWith(
                                            height: 1.35,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Uses your phone’s Share sheet — deliver by iMessage, email, WhatsApp, and more. '
                                    'Recipients with ParentLedger installed open the app directly.',
                                    style: PLDesign.body.copyWith(
                                      color: Colors.white70,
                                      height: 1.4,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _shareInvite,
                              icon: const Icon(Icons.share_rounded, size: 22),
                              label: const Text('Invite Co-Parent'),
                              style: FilledButton.styleFrom(
                                backgroundColor: PLDesign.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _advancing
                                  ? null
                                  : () => showInvitePhoneSheet(
                                        context,
                                        role: 'coparent',
                                      ),
                              child: Text(
                                'Invite by phone instead',
                                style: PLDesign.caption.copyWith(
                                  color: PLDesign.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _advancing ? null : _continueOnboarding,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: PLDesign.primaryGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: PLDesign.primary.withValues(alpha: 0.35),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _advancing
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Continue',
                                  style: PLDesign.buttonText,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _advancing ? null : skip,
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
