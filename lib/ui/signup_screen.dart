import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:parentledger/design/design.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final emailController = TextEditingController();

  String? parentType;
  bool loading = false;

  InputDecoration _fieldDecoration(String hint) {
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

  /// Single border for role — no duplicate container wrapper.
  InputDecoration get _roleDecoration {
    return InputDecoration(
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

  Future<void> _completeSignup() async {
    if (loading) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _error('User not authenticated');
      return;
    }

    if (firstName.text.trim().isEmpty ||
        lastName.text.trim().isEmpty ||
        parentType == null) {
      _error('Complete all fields');
      return;
    }

    setState(() => loading = true);

    try {
      final fn = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = fn.httpsCallable('completeSignup');
      await callable.call(<String, dynamic>{
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'email': emailController.text.trim(),
        'parentType': parentType,
      });
    } on FirebaseFunctionsException catch (e) {
      _error(e.message ?? 'Signup failed');
    } catch (_) {
      _error('Signup failed');
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    emailController.dispose();
    super.dispose();
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
                  const SizedBox(height: 20),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: firstName,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('First name'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: lastName,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Last name'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _fieldDecoration('Email (optional)'),
                  ),
                  const SizedBox(height: 14),
                  InputDecorator(
                    decoration: _roleDecoration,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: parentType,
                        isExpanded: true,
                        dropdownColor: const Color(0xff1c1f2e),
                        style: const TextStyle(color: Colors.white),
                        iconEnabledColor: Colors.white70,
                        hint: const Text(
                          'Select role',
                          style: TextStyle(color: Colors.white54),
                        ),
                        items: [
                          DropdownMenuItem(
                              value: 'mom', child: Text(context.tTone('mom'))),
                          DropdownMenuItem(
                              value: 'dad', child: Text(context.tTone('dad'))),
                          DropdownMenuItem(
                            value: 'guardian',
                            child: Text(context.tTone('guardian')),
                          ),
                        ],
                        onChanged: (v) => setState(() => parentType = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  PLDesign.primaryButton(
                    label: loading ? 'Creating…' : 'Continue',
                    onTap: loading ? () {} : _completeSignup,
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
