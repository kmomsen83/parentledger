import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../app_router.dart';
import '../design/design.dart';
import '../services/coparent_invite_code_service.dart';
import '../services/invite_link_service.dart';
import '../services/invite_service.dart';
import 'accept_invite_screen.dart';

/// Manual invite entry: **co-parent short codes** (6–8 chars) via HTTPS callable,
/// or **legacy** Firestore invite document IDs (long) via [InviteService.validateInvite].
class EnterInviteCodeScreen extends StatefulWidget {
  const EnterInviteCodeScreen({
    super.key,
    this.initialCode,
    this.promptConfirmFromDeepLink = false,
  });

  /// Prefill from deep link ([InviteLinkService.pendingInviteCode]).
  final String? initialCode;

  /// When true (e.g. opened from [AppRouter] after `https://parentledger.org/invite?code=`),
  /// shows a one-time confirmation before the user continues.
  final bool promptConfirmFromDeepLink;

  @override
  State<EnterInviteCodeScreen> createState() => _EnterInviteCodeScreenState();
}

class _EnterInviteCodeScreenState extends State<EnterInviteCodeScreen> {
  late final TextEditingController _controller;
  bool _submitting = false;
  String? _error;
  bool _deepLinkConfirmScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCode ?? '');
    if (widget.promptConfirmFromDeepLink) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptDeepLinkConfirm());
    }
  }

  Future<void> _promptDeepLinkConfirm() async {
    if (!mounted || _deepLinkConfirmScheduled) return;
    final code = widget.initialCode?.trim();
    if (code == null || code.isEmpty) return;
    _deepLinkConfirmScheduled = true;
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: Text(
          'Use this invite code?',
          style: PLDesign.sectionTitle.copyWith(fontSize: 18),
        ),
        content: Text(
          'You opened an invite link. Continue to join using code '
          '${code.toUpperCase()}?',
          style: PLDesign.body.copyWith(height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (go != true) {
      await _abandonDeepLinkAndExit();
    }
  }

  Future<void> _abandonDeepLinkAndExit() async {
    InviteLinkService.consumeCoparentCode();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const AppRouter()),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _looksLikeCoparentCode(String raw) {
    final compact =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return compact.length >= 6 && compact.length <= 8;
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Enter your invite code.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_looksLikeCoparentCode(raw)) {
        final result = await CoparentInviteCodeService.acceptCode(raw);
        if (!mounted) return;
        InviteLinkService.consumeCoparentCode();
        final msg = result.alreadyMember
            ? 'You are already connected to this case.'
            : 'You have joined the case.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const AppRouter()),
          (_) => false,
        );
        return;
      }

      await InviteService.validateInvite(raw);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AcceptInviteScreen(inviteId: raw),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = _mapFirebaseError(e));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _mapFirebaseError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'not-found':
        return 'Invite code not found.';
      case 'failed-precondition':
        return e.message ?? 'This code has expired or was already used.';
      case 'permission-denied':
        return e.message ?? 'You cannot use this invite.';
      case 'invalid-argument':
        return e.message ?? 'Check the code and try again.';
      case 'unauthenticated':
        return 'Sign in to use this invite code.';
      default:
        return e.message ?? 'Invite code could not be validated.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.promptConfirmFromDeepLink,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _abandonDeepLinkAndExit();
      },
      child: Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: PLDesign.textPrimary,
        title: Text(
          'Enter Invite Code',
          style: PLDesign.sectionTitle.copyWith(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the co-parent invite code from your partner, or a longer legacy invite ID.',
              style: PLDesign.body.copyWith(height: 1.35),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              style: PLDesign.body.copyWith(
                fontSize: 18,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: 'Invite code',
                hintText: 'e.g. ABC12XY',
                errorText: _error,
                filled: true,
                fillColor: PLDesign.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: PLDesign.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: PLDesign.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: PLDesign.primary, width: 1.4),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: PLDesign.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
