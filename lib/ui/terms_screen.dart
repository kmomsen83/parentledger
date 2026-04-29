import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../design/design.dart';
import '../onboarding/onboarding_steps.dart';

/// In-app terms: load from [assets/legal/terms_of_service.md], with embedded fallback.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final ScrollController _scroll = ScrollController();

  bool _hasScrolledToBottom = false;
  bool _accepted = false;
  bool _loading = false;
  bool _loadingBody = true;
  String _markdown = _fallbackTermsMarkdown;

  @override
  void initState() {
    super.initState();
    _loadTerms();
    _scroll.addListener(_onScroll);
  }

  Future<void> _loadTerms() async {
    try {
      final s = await rootBundle.loadString('assets/legal/terms_of_service.md');
      if (mounted) {
        setState(() {
          _markdown = s;
          _loadingBody = false;
        });
        _scheduleScrollFitCheck();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingBody = false);
        _scheduleScrollFitCheck();
      }
    }
  }

  /// If the markdown fits on screen, there is nothing to scroll — treat as "read".
  void _scheduleScrollFitCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final pos = _scroll.position;
      if (pos.maxScrollExtent <= 32 && !_hasScrolledToBottom) {
        setState(() => _hasScrolledToBottom = true);
      }
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 32) {
      if (!_hasScrolledToBottom) {
        setState(() => _hasScrolledToBottom = true);
      }
    }
  }

  Future<void> _accept() async {
    if (!_canSubmit || _loading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'termsAccepted': true,
          'termsAcceptedAt': FieldValue.serverTimestamp(),
          'onboardingStep': OnboardingSteps.profileComplete,
        },
        SetOptions(merge: true),
      );

      // Router rebuilds from Firestore snapshot (no stack to pop).
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('couldNotSavePleaseTry'))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canSubmit => _accepted && _hasScrolledToBottom;

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('termsPrivacy')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                _hasScrolledToBottom
                    ? 'Review the agreement below, then accept to continue.'
                    : 'Scroll to the bottom to enable acceptance.',
                style: PLDesign.caption.copyWith(color: PLDesign.textMuted, height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: _loadingBody
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: MarkdownBody(
                          data: _markdown,
                          selectable: true,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: const TextStyle(
                              color: Colors.white70,
                              height: 1.45,
                              fontSize: 14,
                            ),
                            h1: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                            h2: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            listBullet: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _accepted,
                    onChanged: _hasScrolledToBottom
                        ? (v) => setState(() => _accepted = v ?? false)
                        : null,
                    activeColor: PLDesign.primary,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'I agree to the Terms & Privacy Policy',
                        style: TextStyle(
                          color: _hasScrolledToBottom ? Colors.white70 : PLDesign.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Opacity(
                opacity: _canSubmit ? 1 : 0.45,
                child: PLDesign.primaryButton(
                  label: _loading ? 'Saving…' : 'Accept & continue',
                  onTap: _canSubmit && !_loading ? _accept : () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const String _fallbackTermsMarkdown = '''
# ParentLedger Terms of Service & Privacy

ParentLedger provides tools for co-parents to document events and manage shared responsibilities. ParentLedger is **not** a law firm or legal advisor.

Subscriptions are processed by Apple App Store and Google Play. See in-app purchase screens for renewal and cancellation.

By accepting, you agree to these terms and to our handling of data as described in the app and store listings.
''';
