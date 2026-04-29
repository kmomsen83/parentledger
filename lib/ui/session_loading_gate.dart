import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';

import '../providers/case_context.dart';

/// Shown while [CaseContext.sessionReadyForRouter] is false.
/// Includes status copy and a timeout with retry.
class SessionLoadingGate extends StatefulWidget {
  const SessionLoadingGate({super.key});

  @override
  State<SessionLoadingGate> createState() => _SessionLoadingGateState();
}

class _SessionLoadingGateState extends State<SessionLoadingGate> {
  static const Duration _timeout = Duration(seconds: 9);
  Timer? _timer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_timeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final phase = session.userDocLoading
        ? 'Setting up your account...'
        : 'Checking subscription...';

    return Scaffold(
      backgroundColor: const Color(0xff0c0e14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Color(0xff4f7cff),
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _timedOut ? 'Still working…' : phase,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _timedOut
                    ? 'This is taking longer than usual. You can retry or wait a moment.'
                    : 'Hang tight — we’re connecting your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              if (_timedOut)
                FilledButton.icon(
                  onPressed: () async {
                    setState(() => _timedOut = false);
                    _timer?.cancel();
                    _timer = Timer(_timeout, () {
                      if (mounted) setState(() => _timedOut = true);
                    });
                    await context.read<CaseContext>().retrySessionLoading();
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text(context.tTone('retry')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xff4f7cff),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
