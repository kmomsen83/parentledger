import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../enter_invite_code_screen.dart';

/// Counsel profile after account type — no custody case creation here.
class AttorneyOnboardingScreen extends StatefulWidget {
  const AttorneyOnboardingScreen({super.key});

  @override
  State<AttorneyOnboardingScreen> createState() => _AttorneyOnboardingScreenState();
}

class _AttorneyOnboardingScreenState extends State<AttorneyOnboardingScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _firm = TextEditingController();
  final _bar = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _firm.dispose();
    _bar.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool thenOpenInvite}) async {
    if (_loading) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fn = _firstName.text.trim();
    final ln = _lastName.text.trim();
    if (fn.isEmpty || ln.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your first and last name')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('completeAttorneyOnboarding');
      await callable.call(<String, dynamic>{
        'firstName': fn,
        'lastName': ln,
        'firmName': _firm.text.trim(),
        'barNumber': _bar.text.trim(),
      });
      if (!mounted) return;
      if (thenOpenInvite) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const EnterInviteCodeScreen(),
          ),
        );
      }
      // Router will switch to AttorneyDashboardScreen when step updates.
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Could not save profile')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xff4f7cff), width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(decoration: PLDesign.screenGradient),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attorney profile',
                    style: PLDesign.heroTitle.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Used for your counsel workspace and client sharing.',
                    style: PLDesign.body.copyWith(
                      color: Colors.white70,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('First name'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Last name'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _firm,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Firm name (optional)'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _bar,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Bar / license ID (optional)'),
                  ),
                  const SizedBox(height: 32),
                  PLDesign.primaryButton(
                    label: _loading ? 'Saving…' : 'Continue to dashboard',
                    onTap: _loading ? () {} : () => _submit(thenOpenInvite: false),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => _submit(thenOpenInvite: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Enter client invite code',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
