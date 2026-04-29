import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';

import '../design/design.dart';
import 'recent_activity_timeline_screen.dart';

class ComplianceReportScreen extends StatelessWidget {
  const ComplianceReportScreen({super.key});

  Widget _metricTile(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PLDesign.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: PLDesign.caption.copyWith(
                color: PLDesign.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _issueRow(String title, String date, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: PLDesign.body.copyWith(color: Colors.white))),
          Text(date, style: PLDesign.caption),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('complianceReport')),
        backgroundColor: PLDesign.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff0ea5e9), Color(0xff2563eb)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: PLDesign.softShadow,
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0x33FFFFFF),
                  child: Icon(Icons.verified_rounded, color: Colors.white),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Overall Compliance', style: TextStyle(color: Colors.white70)),
                      SizedBox(height: 4),
                      Text(
                        '91%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Text('Last 30 days', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This report summarizes documented activity only. It is not legal advice.',
            style: PLDesign.caption.copyWith(height: 1.35),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _metricTile('Exchanges', '12', PLDesign.info),
              const SizedBox(width: 8),
              _metricTile('Violations', '1', PLDesign.danger),
              const SizedBox(width: 8),
              _metricTile('Proposals', '3', PLDesign.warning),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _metricTile('Expenses', '5', PLDesign.success),
              const SizedBox(width: 8),
              _metricTile('Messages', '48', PLDesign.ai),
              const SizedBox(width: 8),
              _metricTile('Documents', '2', Colors.tealAccent),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Flagged Events', style: PLDesign.sectionTitle),
          const SizedBox(height: 10),
          _issueRow('Late Exchange', 'Mar 4', PLDesign.danger),
          _issueRow('Tone escalation warning', 'Mar 2', PLDesign.warning),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PLDesign.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PLDesign.border),
            ),
            child: Text(
              'AI narrative: compliance remains strong. One exchange delay was documented and resolved. Communication tone is trending stable compared to the prior period.',
              style: PLDesign.caption.copyWith(height: 1.35),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RecentActivityTimelineScreen(),
                      ),
                    );
                  },
                  child: Text(context.tTone('openTimeline')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Report export is available in Legal Export Center.',
                        ),
                      ),
                    );
                  },
                  child: Text(context.tTone('exportLabel')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
