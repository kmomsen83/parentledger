import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../models/account_type.dart';
import '../../models/user_role.dart';
import '../../onboarding/onboarding_steps.dart';
import '../../providers/case_context.dart';

/// Step 1 after authentication: choose Parent vs Attorney (`users/{uid}.role` + `accountType`).
/// Parents continue to [SignupScreen]; attorneys enter counsel onboarding.
class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  AccountType? _selected;
  bool _saving = false;

  Future<void> _continue() async {
    final choice = _selected;
    if (choice == null || _saving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (choice == AccountType.parent) {
        await ref.set(<String, dynamic>{
          'role': UserRole.parent.name,
          'accountType': AccountType.parent.firestoreValue,
          'onboardingStep': OnboardingSteps.newUser,
        }, SetOptions(merge: true));
      } else {
        await ref.set(<String, dynamic>{
          'role': UserRole.attorney.name,
          'accountType': AccountType.attorney.firestoreValue,
          'onboardingStep': OnboardingSteps.attorneyProfile,
        }, SetOptions(merge: true));
      }
      if (!mounted) return;
      await context.read<CaseContext>().refreshUserDocFromServer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _select(AccountType type) {
    HapticFeedback.selectionClick();
    setState(() => _selected = type);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: PLDesign.screenGradient),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(22, 16, 22, 24 + bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'How will you use ParentLedger?',
                        style: PLDesign.heroTitle.copyWith(
                          fontSize: 26,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      )
                          .animate()
                          .fadeIn(duration: 320.ms)
                          .slideY(begin: 0.06, curve: Curves.easeOutCubic),
                      const SizedBox(height: 10),
                      Text(
                        'Choose the experience that fits you. You can refine details later.',
                        style: PLDesign.body.copyWith(
                          color: Colors.white70,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 80.ms, duration: 320.ms),
                      const SizedBox(height: 28),
                      _RoleCard(
                        icon: Icons.family_restroom_rounded,
                        title: 'Parent / Co-Parent',
                        description:
                            'Manage schedules, expenses, communication, and court-ready records with your co-parent.',
                        selected: _selected == AccountType.parent,
                        accent: const Color(0xff6ec8ff),
                        onTap: () => _select(AccountType.parent),
                      )
                          .animate()
                          .fadeIn(delay: 120.ms, duration: 360.ms)
                          .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                      const SizedBox(height: 16),
                      _RoleCard(
                        icon: Icons.gavel_rounded,
                        title: 'Attorney',
                        description:
                            'Manage client cases, timelines, documents, exports, and legal communication tools.',
                        selected: _selected == AccountType.attorney,
                        accent: const Color(0xffc4a86a),
                        onTap: () => _select(AccountType.attorney),
                      )
                          .animate()
                          .fadeIn(delay: 180.ms, duration: 360.ms)
                          .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                      SizedBox(
                          height: (constraints.maxHeight * 0.06).clamp(20, 56)),
                      FilledButton(
                        onPressed:
                            _selected == null || _saving ? null : _continue,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: PLDesign.primary,
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.12),
                          elevation: _selected == null ? 0 : 3,
                          shadowColor: PLDesign.primary.withValues(alpha: 0.45),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Continue',
                                style: PLDesign.sectionTitle.copyWith(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: accent.withValues(alpha: 0.2),
        highlightColor: accent.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.2),
              width: selected ? 2.4 : 1,
            ),
            color: selected
                ? accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.05),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 22,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PLDesign.sectionTitle.copyWith(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: PLDesign.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.45,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: accent, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
