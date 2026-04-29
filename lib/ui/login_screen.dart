import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'enter_invite_code_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();

  String verificationId = "";
  bool codeSent = false;
  bool sendingCode = false;
  bool verifyingCode = false;
  bool _primaryPressed = false;

  Future<void> sendCode() async {
    final digits = phone.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length < 10) {
      _error('Enter valid phone number');
      return;
    }

    String e164;
    if (digits.length == 10) {
      e164 = '+1$digits';
    } else if (digits.startsWith('1') && digits.length == 11) {
      e164 = '+$digits';
    } else {
      e164 = '+$digits';
    }

    setState(() => sendingCode = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: e164,
      verificationCompleted: (cred) async {
        await FirebaseAuth.instance.signInWithCredential(cred);
        if (!mounted) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      verificationFailed: (e) {
        _error(e.message ?? 'Failed');
        if (mounted) setState(() => sendingCode = false);
      },
      codeSent: (id, _) {
        verificationId = id;
        if (mounted) {
          setState(() {
            codeSent = true;
            sendingCode = false;
          });
        }
      },
      codeAutoRetrievalTimeout: (id) {
        verificationId = id;
      },
    );
  }

  Future<void> verifyCode() async {
    setState(() => verifyingCode = true);
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(cred);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _error('Invalid code');
    } finally {
      if (mounted) setState(() => verifyingCode = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool get _busy => sendingCode || verifyingCode;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    16,
                    28,
                    bottomInset + 24,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                      minHeight: constraints.maxHeight -
                          MediaQuery.of(context).padding.vertical,
                    ),
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
                        const SizedBox(height: 36),
                        _authTextField(),
                        const SizedBox(height: 12),
                        if (codeSent)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() {
                                      codeSent = false;
                                      code.clear();
                                    });
                                  },
                            child: const Text(
                              'Change number',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (!codeSent) const SizedBox(height: 8),
                        const SizedBox(height: 16),
                        _primaryButton(),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const EnterInviteCodeScreen(),
                                    ),
                                  );
                                },
                          child: const Text(
                            'Enter Invite Code',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _authTextField() {
    final isCode = codeSent;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: isCode ? code : phone,
        keyboardType: isCode ? TextInputType.number : TextInputType.phone,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: isCode ? '6-digit code' : 'Mobile number',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          isDense: false,
        ),
      ),
    );
  }

  Widget _primaryButton() {
    final label = codeSent ? 'Verify' : 'Send code';
    final showSendSpinner = sendingCode && !codeSent;
    final showVerifySpinner = verifyingCode && codeSent;
    final showSpinner = showSendSpinner || showVerifySpinner;

    return Listener(
      onPointerDown: (_) => setState(() => _primaryPressed = true),
      onPointerUp: (_) => setState(() => _primaryPressed = false),
      onPointerCancel: (_) => setState(() => _primaryPressed = false),
      child: AnimatedScale(
        scale: _primaryPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _busy ? 0.75 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _busy
                  ? null
                  : () {
                      if (codeSent) {
                        verifyCode();
                      } else {
                        sendCode();
                      }
                    },
              borderRadius: BorderRadius.circular(30),
              splashColor: Colors.white.withValues(alpha: 0.2),
              highlightColor: Colors.white.withValues(alpha: 0.1),
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
                      color: const Color(0xff3d7cff).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: showSpinner
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          label,
                          style: const TextStyle(
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
    );
  }

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }
}
