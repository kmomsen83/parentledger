import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../models/user_role.dart';
import '../../onboarding/onboarding_steps.dart';

/// Step 1 after authentication: choose Parent vs Attorney (`users/{uid}.role`).
/// Parents continue to [SignupScreen]; attorneys go to [AttorneyOnboardingScreen].
class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  UserRole? _selected;
  bool _saving = false;

  Future<void> _continue() async {
    final choice = _selected;
    if (choice == null || _saving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (choice == UserRole.parent) {
        await ref.set(<String, dynamic>{
          'role': 'parent',
          'onboardingStep': OnboardingSteps.newUser,
        }, SetOptions(merge: true));
      } else {
        await ref.set(<String, dynamic>{
          'role': 'attorney',
          'onboardingStep': OnboardingSteps.attorneyProfile,
        }, SetOptions(merge: true));
      }
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
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'How will you use ParentLedger?',
                    style: PLDesign.heroTitle.copyWith(fontSize: 26, height: 1.2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choose your account type. You can update counsel settings later.',
                    style: PLDesign.body.copyWith(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _AccountTypeCard(
                            icon: Icons.family_restroom_rounded,
                            title: 'Parent / Co-Parent',
                            description:
                                'Track custody messaging, expenses, and schedules',
                            selected: _selected == UserRole.parent,
                            onTap: () =>
                                setState(() => _selected = UserRole.parent),
                          ),
                          const SizedBox(height: 16),
                          _AccountTypeCard(
                            icon: Icons.balance_rounded,
                            title: 'Attorney',
                            description:
                                'Counsel workspace — review client cases and exports',
                            selected: _selected == UserRole.attorney,
                            onTap: () =>
                                setState(() => _selected = UserRole.attorney),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed:
                        _selected == null || _saving ? null : _continue,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: PLDesign.primary,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.12),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? PLDesign.primary
                  : Colors.white.withValues(alpha: 0.22),
              width: selected ? 2.2 : 1,
            ),
            color: selected
                ? PLDesign.primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
            boxShadow: selected ? PLDesign.softShadow : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected
                      ? PLDesign.primary.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PLDesign.sectionTitle.copyWith(
                        fontSize: 19,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: PLDesign.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.4,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    color: PLDesign.primary, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
