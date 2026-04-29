import 'package:flutter/foundation.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/design.dart';
import '../onboarding/onboarding_steps.dart';

class WorkspaceCoparentSetupScreen extends StatefulWidget {
  const WorkspaceCoparentSetupScreen({super.key});

  @override
  State<WorkspaceCoparentSetupScreen> createState() =>
      _WorkspaceCoparentSetupScreenState();
}

class _WorkspaceCoparentSetupScreenState
    extends State<WorkspaceCoparentSetupScreen> {
  final phone = TextEditingController();
  bool loading = false;

  String normalize(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 8 && digits.length <= 15) {
      return '+$digits';
    }
    return '';
  }

  bool isValidPhone(String phone) {
    return RegExp(r'^\+\d{8,15}$').hasMatch(phone);
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration get _phoneDecoration {
    return InputDecoration(
      hintText: 'Enter phone number',
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
      filled: true,
      fillColor: PLDesign.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: PLDesign.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: PLDesign.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xff4f7cff), width: 1.2),
      ),
    );
  }

  Future<void> sendInvite() async {
    if (loading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error('User not authenticated');
      return;
    }

    final db = FirebaseFirestore.instance;
    final normalized = normalize(phone.text.trim());

    if (phone.text.trim().isEmpty) {
      _error('Phone number is required');
      return;
    }

    if (!isValidPhone(normalized)) {
      _error('Use a valid number with country code (e.g. +1…)');
      return;
    }

    setState(() => loading = true);

    try {
      final userDoc = await db.collection('users').doc(user.uid).get();
      final data = userDoc.data();

      if (data == null || data['caseId'] == null) {
        throw Exception('Missing caseId');
      }

      final caseId = data['caseId'] as String;

      final fn = data['firstName']?.toString().trim() ?? '';
      final ln = data['lastName']?.toString().trim() ?? '';
      final fromDisplayName = [fn, ln].where((s) => s.isNotEmpty).join(' ');

      final inviteRef = await db.collection('caseInvites').add({
        'fromUserId': user.uid,
        if (fromDisplayName.isNotEmpty) 'fromDisplayName': fromDisplayName,
        'toPhone': normalized,
        'role': 'coparent',
        'status': 'pending',
        'caseId': caseId,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
        'acceptedBy': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final link = 'https://parentledger.app/invite?id=${inviteRef.id}';
      final message = 'Join me on ParentLedger: $link';

      if (!mounted) return;

      final openExternal = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: PLDesign.surface,
          title: Text(
            normalized.isNotEmpty ? 'Open SMS?' : 'Open invite link?',
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            normalized.isNotEmpty
                ? 'We’ll open your SMS app with a draft message. You can edit it before sending.'
                : 'We’ll open your invite link so you can share it any way you like (text, email, etc.).',
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tTone('notNow')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(normalized.isNotEmpty ? 'Open SMS' : 'Open link'),
            ),
          ],
        ),
      );

      if (openExternal == true) {
        if (normalized.isNotEmpty) {
          final smsUri = Uri(
            scheme: 'sms',
            path: normalized,
            queryParameters: {'body': message},
          );

          if (await canLaunchUrl(smsUri)) {
            await launchUrl(smsUri);
          } else {
            await launchUrl(
              Uri.parse(link),
              mode: LaunchMode.externalApplication,
            );
          }
        } else {
          await launchUrl(
            Uri.parse(link),
            mode: LaunchMode.externalApplication,
          );
        }
      }

      await db.collection('users').doc(user.uid).update({
        'onboardingStep': OnboardingSteps.coparentInvited,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('inviteSavedInviteLinkIs'))),
      );
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Invite send failed');
      }
      _error('Failed to send invite');
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> skip() async {
    if (loading) return;

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

    setState(() => loading = true);

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
      _error('Failed to continue');
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
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
                    'Connect co-parent',
                    style: PLDesign.pageTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You can invite your co-parent now or later from Profile → Invite Co-Parent.',
                    style: PLDesign.body.copyWith(height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Phone is required for secure invite acceptance. We never send a message without your confirmation.',
                    style: PLDesign.caption.copyWith(
                      color: Colors.white54,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: _phoneDecoration,
                  ),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: loading ? null : sendInvite,
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
                        child: loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Send invite',
                                style: PLDesign.buttonText,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: loading ? null : skip,
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(color: Colors.white70),
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
