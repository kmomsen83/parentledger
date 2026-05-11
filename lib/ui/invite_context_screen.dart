import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../design/design.dart';
import '../design/pl_premium_components.dart';
import '../onboarding/onboarding_steps.dart';

/// Shown after accepting a co-parent invite, before create account / terms.
class InviteContextScreen extends StatefulWidget {
  const InviteContextScreen({super.key});

  @override
  State<InviteContextScreen> createState() => _InviteContextScreenState();
}

class _InviteContextScreenState extends State<InviteContextScreen> {
  bool _loading = true;
  bool _saving = false;
  String _inviterLabel = 'your co-parent';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = doc.data()?['inviterDisplayName'] as String?;
      if (name != null && name.trim().isNotEmpty && mounted) {
        setState(() => _inviterLabel = name.trim());
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _continue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'onboardingStep': OnboardingSteps.newUser},
        SetOptions(merge: true),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tTone('couldNotContinuePleaseTry')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Icon(
                          Icons.mark_email_read_outlined,
                          size: 52,
                          color: PLDesign.primary.withValues(alpha: 0.9),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "You've been invited",
                          style: PLDesign.pageTitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "You're joining $_inviterLabel's shared parenting workspace.",
                          style: PLDesign.body.copyWith(
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        _bullet(
                          Icons.family_restroom_outlined,
                          'Shared children and schedules stay in one place.',
                        ),
                        const SizedBox(height: 14),
                        _bullet(
                          Icons.folder_shared_outlined,
                          'Records and activity you add are visible to members of this case.',
                        ),
                        const SizedBox(height: 14),
                        _bullet(
                          Icons.verified_user_outlined,
                          'A subscription unlocks the full toolkit; you can review plans later.',
                        ),
                        const SizedBox(height: 36),
                        Text(
                          'Next: create your profile, accept terms, add your children, then choose a plan or start with limited access.',
                          style: PLDesign.caption.copyWith(height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        PLPrimaryButton(
                          label: _saving ? 'Continuing…' : 'Continue setup',
                          onPressed: _saving ? null : _continue,
                          enabled: !_saving,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: PLDesign.body.copyWith(height: 1.35, color: Colors.white70),
          ),
        ),
      ],
    );
  }
}
