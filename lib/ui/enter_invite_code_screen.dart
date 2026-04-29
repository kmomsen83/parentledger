import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/invite_service.dart';
import 'accept_invite_screen.dart';

class EnterInviteCodeScreen extends StatefulWidget {
  const EnterInviteCodeScreen({super.key});

  @override
  State<EnterInviteCodeScreen> createState() => _EnterInviteCodeScreenState();
}

class _EnterInviteCodeScreenState extends State<EnterInviteCodeScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final inviteId = _controller.text.trim();
    if (inviteId.isEmpty) {
      setState(() => _error = 'Enter your invite code.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await InviteService.validateInvite(inviteId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => AcceptInviteScreen(inviteId: inviteId)),
      );
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = _mapError(e.code));
    } catch (_) {
      setState(() => _error = 'Could not validate invite code right now.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'not-found':
        return 'Invite code not found.';
      case 'failed-precondition':
        return 'Invite is expired or already accepted.';
      case 'permission-denied':
        return 'Invite is assigned to another account.';
      case 'unauthenticated':
        return 'Sign in to use this invite code.';
      default:
        return 'Invite code could not be validated.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Invite Code')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste your invite code to recover and join your case.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Invite code',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Checking...' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
