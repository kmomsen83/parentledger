import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';

import '../design/design.dart';
import 'ai_fairness_suggestion_screen.dart';
import 'compliance_forecast_screen.dart';
import 'compromise_history_screen.dart';
import 'compliance_report_screen.dart';

class CompromiseDashboardScreen extends StatelessWidget {
  const CompromiseDashboardScreen({super.key});

  Widget _moduleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: PLDesign.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PLDesign.border),
            boxShadow: PLDesign.softShadow,
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PLDesign.sectionTitle.copyWith(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: PLDesign.caption.copyWith(height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _negotiationTile({
    required String title,
    required String status,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.handshake_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: PLDesign.body.copyWith(color: Colors.white))),
          Text(
            status,
            style: PLDesign.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('compromiseCenter')),
        backgroundColor: PLDesign.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff4A6CF7), Color(0xff7A8BFF)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: PLDesign.softShadow,
            ),
            child: const Row(
              children: [
                Icon(Icons.balance_rounded, color: Colors.white, size: 34),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Compromise Health', style: TextStyle(color: Colors.white70)),
                      SizedBox(height: 4),
                      Text(
                        '76%',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.psychology_alt_rounded, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Use these tools to de-escalate conflict and document constructive resolution.',
            style: PLDesign.caption.copyWith(height: 1.35),
          ),
          const SizedBox(height: 16),
          _moduleCard(
            context,
            icon: Icons.psychology_alt_rounded,
            title: 'AI Fairness Engine',
            subtitle: 'See balanced language and proposal framing suggestions.',
            accent: PLDesign.ai,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiFairnessSuggestionScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _moduleCard(
            context,
            icon: Icons.auto_graph_rounded,
            title: 'Compliance Forecast',
            subtitle: 'Predict upcoming friction windows before they escalate.',
            accent: PLDesign.info,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComplianceForecastScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _moduleCard(
            context,
            icon: Icons.history_rounded,
            title: 'Compromise History',
            subtitle: 'Review acceptance trends and recurring dispute patterns.',
            accent: PLDesign.warning,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompromiseHistoryScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _moduleCard(
            context,
            icon: Icons.fact_check_outlined,
            title: 'Compliance Report',
            subtitle: 'Generate a narrative summary for legal and case review.',
            accent: PLDesign.success,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComplianceReportScreen()),
            ),
          ),
          const SizedBox(height: 22),
          const Text('Active Negotiations', style: PLDesign.sectionTitle),
          const SizedBox(height: 10),
          _negotiationTile(
            title: 'Schedule Adjustment',
            status: 'Pending response',
            color: PLDesign.warning,
          ),
          _negotiationTile(
            title: 'Expense Split Discussion',
            status: 'In progress',
            color: PLDesign.info,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PLDesign.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PLDesign.border),
            ),
            child: Text(
              'AI insight: recent proposal acceptance is improving after neutral, logistics-first messaging. Keep requests specific and time-bound.',
              style: PLDesign.caption.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
