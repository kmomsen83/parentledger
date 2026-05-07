import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../app_router.dart';
import '../design/design.dart';
import 'entry_screen.dart';
import '../services/invite_service.dart';

class AcceptInviteScreen extends StatefulWidget {
  final String inviteId;

  const AcceptInviteScreen({super.key, required this.inviteId});

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  bool loading = true;
  bool joining = false;
  bool _autoAcceptTried = false;

  Map<String, dynamic>? inviteData;
  String? error;

  @override
  void initState() {
    super.initState();
    loadInvite();
  }

  Future<void> loadInvite() async {
    try {
      setState(() {
        error = null;
        loading = true;
      });
      inviteData = await InviteService.validateInvite(widget.inviteId);
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      if (!_autoAcceptTried && FirebaseAuth.instance.currentUser != null) {
        _autoAcceptTried = true;
        unawaited(acceptInvite());
      }
    } catch (e) {
      final message = _inviteErrorMessage(e);
      setState(() {
        error = message;
        loading = false;
      });
    }
  }

  Future<void> acceptInvite() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const EntryScreen(),
        ),
      );
      return;
    }

    setState(() => joining = true);

    try {
      await InviteService.acceptInvite(widget.inviteId);
      developer.log(
        'acceptInvite ok inviteId=${widget.inviteId}',
        name: 'InviteDeepLink',
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppRouter()),
        (_) => false,
      );
    } catch (e) {
      final message = _inviteErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }

    if (mounted) setState(() => joining = false);
  }

  void _backToSignIn() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EntryScreen()),
    );
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
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : error != null
                      ? _ErrorView(
                          message: error!,
                          onBack: _backToSignIn,
                        )
                      : _InviteView(
                          inviteData: inviteData,
                          joining: joining,
                          onAccept: acceptInvite,
                        ),
            ),
          ),
        ],
      ),
    );
  }

  String _inviteErrorMessage(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'not-found':
          return 'This invite code is invalid.';
        case 'failed-precondition':
          return 'This invite is expired or already accepted.';
        case 'permission-denied':
          return 'This invite is assigned to a different account.';
        case 'unauthenticated':
          return 'Sign in first to accept this invite.';
      }
    }
    return 'We could not process this invite right now. Please try again.';
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onBack,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.link_off,
            size: 56, color: Colors.white.withValues(alpha: 0.35)),
        const SizedBox(height: 20),
        Text(
          message,
          textAlign: TextAlign.center,
          style: PLDesign.body.copyWith(height: 1.45),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: onBack,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: PLDesign.primary,
          ),
          child: Text(context.tTone('backToSignIn')),
        ),
      ],
    );
  }
}

class _InviteView extends StatelessWidget {
  const _InviteView({
    required this.inviteData,
    required this.joining,
    required this.onAccept,
  });

  final Map<String, dynamic>? inviteData;
  final bool joining;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final name = inviteData?['fromDisplayName'] as String?;
    final inviterLine = name != null && name.trim().isNotEmpty
        ? '$name invited you to join their ParentLedger workspace.'
        : 'You’ve been invited to join a shared ParentLedger workspace.';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: PLDesign.primary.withValues(alpha: 0.95),
        ),
        const SizedBox(height: 24),
        const Text(
          'Join workspace',
          style: PLDesign.pageTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          inviterLine,
          style: PLDesign.body.copyWith(height: 1.45),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Next you’ll confirm your profile, agree to terms, and review your children. You can add Pro later.',
          style: PLDesign.caption.copyWith(height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        FilledButton(
          onPressed: joining ? null : onAccept,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: PLDesign.primary,
          ),
          child: Text(joining ? 'Joining…' : 'Accept & continue'),
        ),
      ],
    );
  }
}
