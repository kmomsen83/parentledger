import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../app_router.dart';
import '../../design/design.dart';
import '../../services/case_messaging_service.dart';
import '../../services/invite_link_service.dart';
import '../../services/invite_service.dart';
import '../entry_screen.dart';

class AcceptInviteTokenScreen extends StatefulWidget {
  const AcceptInviteTokenScreen({
    super.key,
    required this.token,
    this.onFlowFinished,
  });

  final String token;
  final VoidCallback? onFlowFinished;

  @override
  State<AcceptInviteTokenScreen> createState() => _AcceptInviteTokenScreenState();
}

class _AcceptInviteTokenScreenState extends State<AcceptInviteTokenScreen> {
  bool _loading = true;
  bool _accepting = false;
  bool _declining = false;
  bool _autoAcceptAttempted = false;
  bool _autoConnecting = false;
  String? _error;
  Map<String, dynamic>? _invite;
  String _inviteKind = '';

  @override
  void initState() {
    super.initState();
    developer.log(
      'accept_invite_screen token_prefix=${widget.token.length >= 8 ? widget.token.substring(0, 8) : widget.token}',
      name: 'InviteFlow',
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      developer.log('validateCaseInviteToken begin', name: 'InviteFlow');
      final invite = await InviteService.validateCaseInviteToken(widget.token);
      if (!mounted) return;
      _inviteKind = (invite['inviteKind'] ?? '').toString();
      final signedIn = FirebaseAuth.instance.currentUser != null;
      if (signedIn && !_autoAcceptAttempted) {
        _autoAcceptAttempted = true;
        setState(() {
          _invite = invite;
          _loading = false;
          _autoConnecting = true;
        });
        developer.log(
          'validateCaseInviteToken ok inviteKind=$_inviteKind → auto_accept',
          name: 'InviteFlow',
        );
        await _accept();
        return;
      }
      setState(() {
        _invite = invite;
        _loading = false;
      });
      developer.log(
        'validateCaseInviteToken ok inviteKind=$_inviteKind (manual accept)',
        name: 'InviteFlow',
      );
    } catch (e, st) {
      developer.log(
        'validateCaseInviteToken failed: ${_errorMessage(e)}',
        name: 'InviteFlow',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      developer.log('acceptCaseInviteToken begin', name: 'InviteFlow');
      final result = await InviteService.acceptCaseInviteToken(widget.token);
      if (!mounted) return;
      final alreadyMember = result['alreadyMember'] == true;
      final caseId = result['caseId']?.toString();
      developer.log(
        'acceptCaseInviteToken ok caseId=$caseId role=${result['role']} alreadyMember=$alreadyMember',
        name: 'InviteFlow',
      );
      if (caseId != null && caseId.isNotEmpty) {
        try {
          await CaseMessagingService.ensureCaseThreads(caseId);
          developer.log(
            'ensureCaseThreads ok caseId=$caseId',
            name: 'InviteFlow',
          );
        } catch (e, st) {
          developer.log(
            'ensureCaseThreads failed caseId=$caseId',
            name: 'InviteFlow',
            error: e,
            stackTrace: st,
          );
        }
      }
      if (alreadyMember && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are already connected to this workspace.'),
          ),
        );
      }
      widget.onFlowFinished?.call();
      InviteLinkService.consume();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppRouter()),
        (_) => false,
      );
    } catch (e, st) {
      developer.log(
        'acceptCaseInviteToken failed: ${_errorMessage(e)}',
        name: 'InviteFlow',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _accepting = false;
          _autoConnecting = false;
        });
      }
    }
  }

  Future<void> _decline() async {
    setState(() => _declining = true);
    try {
      if (_inviteKind == 'coparentFirestore') {
        await InviteService.declineCoparentInviteToken(widget.token);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update invite.')),
        );
      }
    } finally {
      if (mounted) setState(() => _declining = false);
    }
    widget.onFlowFinished?.call();
    InviteLinkService.consume();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppRouter()),
      (_) => false,
    );
  }

  String _inviterDisplay() {
    final raw = (_invite?['fromDisplayName'] ?? '').toString().trim();
    return raw.isEmpty ? 'your co-parent' : raw;
  }

  List<String> _childNames() {
    final raw = _invite?['children'];
    if (raw is! List) return [];
    final out = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final n = item['name']?.toString().trim();
        if (n != null && n.isNotEmpty) out.add(n);
      }
    }
    return out;
  }

  String? _photoUrl() {
    final u = (_invite?['fromPhotoUrl'] ?? '').toString().trim();
    return u.isEmpty ? null : u;
  }

  String _errorMessage(Object e) {
    if (e is SocketException || e is TimeoutException) {
      return 'Network problem. Check your connection and try again.';
    }
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'not-found':
          return 'Invite not found.';
        case 'failed-precondition':
          return e.message ?? 'Invite expired or already used.';
        case 'unauthenticated':
          return 'Please sign in to continue.';
        case 'permission-denied':
          return 'You are not allowed to use this invite.';
        case 'unavailable':
          return 'Service temporarily unavailable. Try again shortly.';
      }
    }
    return 'Unable to process invite right now.';
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
              padding: const EdgeInsets.all(24),
              child: _loading || _autoConnecting
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 22),
                        Text(
                          _autoConnecting
                              ? 'Connecting your workspace…'
                              : 'Checking invite…',
                          textAlign: TextAlign.center,
                          style: PLDesign.body.copyWith(height: 1.45),
                        ),
                      ],
                    )
                  : _error != null
                      ? _errorCard(context)
                      : _content(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off_rounded,
              color: Colors.white.withValues(alpha: 0.45), size: 52),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: PLDesign.body.copyWith(height: 1.45),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              widget.onFlowFinished?.call();
              InviteLinkService.consume();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const EntryScreen()),
              );
            },
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final children = _childNames();
    final photo = _photoUrl();
    final name = _inviterDisplay();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: _accepting || _declining
                ? null
                : () {
                    widget.onFlowFinished?.call();
                    InviteLinkService.consume();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const EntryScreen()),
                    );
                  },
            icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.75)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Secure invite',
          textAlign: TextAlign.center,
          style: PLDesign.caption.copyWith(
            color: PLDesign.primary.withValues(alpha: 0.95),
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Connect your workspace',
          textAlign: TextAlign.center,
          style: PLDesign.pageTitle.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: PLDesign.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: PLDesign.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 28,
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white12,
                backgroundImage: photo != null
                    ? CachedNetworkImageProvider(photo)
                    : null,
                child: photo == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              Text(
                'Connect with $name?',
                textAlign: TextAlign.center,
                style: PLDesign.sectionTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 14),
              if (children.isNotEmpty) ...[
                Text(
                  'Children on this workspace',
                  style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: children
                      .map(
                        (n) => Chip(
                          label: Text(n),
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.06),
                          side: BorderSide.none,
                          labelStyle: PLDesign.caption,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PLDesign.primary.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: PLDesign.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: PLDesign.primary.withValues(alpha: 0.95),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'End-to-end secure connection\nCourt-ready communication enabled',
                        style: PLDesign.caption.copyWith(
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: (_accepting || _declining) ? null : _accept,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: PLDesign.primary,
          ),
          child: Text(_accepting ? 'Connecting…' : 'Accept Connection'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: (_accepting || _declining) ? null : _decline,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Text(_declining ? 'Declining…' : 'Decline'),
        ),
      ],
    );
  }
}
