import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_router.dart';
import '../services/invite_link_service.dart';
import 'login_screen.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  bool checking = true;
  bool _ctaPressed = false;

  @override
  void initState() {
    super.initState();
    _handleEntry();
  }

  bool get _hasQueuedInvite =>
      InviteLinkService.pendingInviteToken.value != null ||
      InviteLinkService.pendingInviteCode.value != null ||
      InviteLinkService.pendingInviteId.value != null;

  Future<void> _handleEntry() async {
    final user = FirebaseAuth.instance.currentUser;

    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    if (user == null) {
      setState(() => checking = false);
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const AppRouter(),
      ),
    );
  }

  Future<void> _startLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
    if (!mounted) return;
    await _handleEntry();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/design/premium_entry_screen_background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          SafeArea(
            child: Center(
              child: checking
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'ParentLedger',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Custody. Clarity. Peace.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 50),
                          Listener(
                            onPointerDown: (_) =>
                                setState(() => _ctaPressed = true),
                            onPointerUp: (_) =>
                                setState(() => _ctaPressed = false),
                            onPointerCancel: (_) =>
                                setState(() => _ctaPressed = false),
                            child: AnimatedScale(
                              scale: _ctaPressed ? 0.98 : 1.0,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _startLogin,
                                  borderRadius: BorderRadius.circular(30),
                                  splashColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  highlightColor:
                                      Colors.white.withValues(alpha: 0.1),
                                  child: Ink(
                                    height: 56,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xff76c3ff),
                                          Color(0xff3d7cff),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xff3d7cff)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Continue with Phone',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_hasQueuedInvite)
                            const Text(
                              'Secure co-parent invite ready — sign in to connect.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
