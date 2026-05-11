import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../providers/case_context.dart';
import 'paywall_screen.dart';
import 'dashboard_screen.dart';

class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  bool loading = true;
  bool isPremium = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runGateCheck());
  }

  Future<void> _runGateCheck() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => loading = false);
        return;
      }

      if (!mounted) return;
      final session = context.read<CaseContext>();
      await session.refreshPremiumStatus();
      if (!mounted) return;

      setState(() {
        // Attorneys bypass the parent subscription gate entirely.
        isPremium = session.isAttorney || session.hasFullAccess;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (isPremium) {
      return const DashboardScreen();
    }

    return const PaywallScreen();
  }
}
