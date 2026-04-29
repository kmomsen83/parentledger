import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_router.dart';
import '../../design/design.dart';
import '../../services/invite_service.dart';
import '../entry_screen.dart';

class AcceptInviteTokenScreen extends StatefulWidget {
  const AcceptInviteTokenScreen({super.key, required this.token});

  final String token;

  @override
  State<AcceptInviteTokenScreen> createState() => _AcceptInviteTokenScreenState();
}

class _AcceptInviteTokenScreenState extends State<AcceptInviteTokenScreen> {
  bool _loading = true;
  bool _accepting = false;
  String? _error;
  Map<String, dynamic>? _invite;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite = await InviteService.validateCaseInviteToken(widget.token);
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _loading = false;
      });
    } catch (e) {
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
      final result = await InviteService.acceptCaseInviteToken(widget.token);
      if (!mounted) return;
      final alreadyMember = result['alreadyMember'] == true;
      if (alreadyMember) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already in this case.')),
        );
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppRouter()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(
      ClipboardData(text: 'https://parentledger.app/invite?token=${widget.token}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied')),
    );
  }

  Future<void> _shareLink() async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Join my ParentLedger case: https://parentledger.app/invite?token=${widget.token}',
      ),
    );
  }

  String _errorMessage(Object e) {
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
      }
    }
    return 'Unable to process invite right now.';
  }

  @override
  Widget build(BuildContext context) {
    final role = (_invite?['role'] ?? '').toString().trim().toLowerCase();
    final roleLabel = role == 'attorney' ? 'Attorney' : 'Co-parent';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: PLDesign.screenGradient),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _error != null
                      ? _errorCard(context)
                      : _inviteCard(roleLabel),
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
          const Icon(Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: PLDesign.body,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
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

  Widget _inviteCard(String roleLabel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "You've been invited to join a case",
          textAlign: TextAlign.center,
          style: PLDesign.pageTitle,
        ),
        const SizedBox(height: 12),
        Text(
          'You will join as $roleLabel.',
          textAlign: TextAlign.center,
          style: PLDesign.body,
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _accepting ? null : _accept,
          child: Text(_accepting ? 'Accepting...' : 'Accept Invite'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _copyLink,
          child: const Text('Copy Link'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _shareLink,
          child: const Text('Share via SMS / Email'),
        ),
      ],
    );
  }
}

