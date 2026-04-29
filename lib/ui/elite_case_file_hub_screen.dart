import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import 'legal_export_center_screen.dart';
import 'expense_report_screen.dart';
import 'recent_activity_timeline_screen.dart';
import 'elite_children_directory_screen.dart';

/// Elite entry point: court-ready exports, live financial intelligence, activity, children.
/// Matches dashboard PLDesign language (gold accent, glass cards).
class EliteCaseFileHubScreen extends StatelessWidget {
  const EliteCaseFileHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final caseId = session.caseId;

    return Scaffold(
      backgroundColor: PLDesign.background,
      body: Container(
        decoration: PLDesign.screenGradient,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
                      ),
                      const Expanded(
                        child: Text(
                          'Case file',
                          style: PLDesign.pageTitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: PLDesign.premiumCaseCardGradient,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: PLDesign.premiumGold.withValues(alpha: 0.42),
                        width: 1.35,
                      ),
                      boxShadow: PLDesign.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.workspace_premium_rounded,
                                color: PLDesign.premiumGold, size: 26),
                            const SizedBox(width: 10),
                            Text(
                              'PRODUCTION RECORDS',
                              style: PLDesign.premiumCaseEyebrow.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          caseId == null
                              ? 'Finish workspace setup to unlock exports tied to your case.'
                              : 'Court-ready packets, live expense intelligence, documented activity, and child profiles — one place.',
                          style: PLDesign.dashboardHeroSubtitle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _hubTile(
                      context,
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'Legal & court exports',
                      subtitle: 'PDF-ready reports for mediation, counsel, or filings',
                      enabled: caseId != null,
                      onTap: () => _push(context, const LegalExportCenterScreen()),
                    ),
                    _hubTile(
                      context,
                      icon: Icons.insights_rounded,
                      title: 'Financial intelligence',
                      subtitle: 'Live expense totals, splits, and filters from your case',
                      enabled: caseId != null,
                      onTap: () => _push(context, const ExpenseReportScreen()),
                    ),
                    _hubTile(
                      context,
                      icon: Icons.timeline_rounded,
                      title: 'Activity & proof trail',
                      subtitle: 'Recent documented events on your case timeline',
                      enabled: caseId != null,
                      onTap: () => _push(context, const RecentActivityTimelineScreen()),
                    ),
                    _hubTile(
                      context,
                      icon: Icons.family_restroom_rounded,
                      title: 'Children on this case',
                      subtitle: 'Profiles, photos, and notes — organized per child',
                      enabled: caseId != null,
                      onTap: () => _push(context, const EliteChildrenDirectoryScreen()),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Widget _hubTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? onTap
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Complete workspace setup so your case is linked.',
                      ),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: PLDesign.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: enabled
                    ? PLDesign.border
                    : PLDesign.border.withValues(alpha: 0.35),
              ),
              boxShadow: PLDesign.softShadow,
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: PLDesign.glassGradient,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: enabled ? PLDesign.primary : PLDesign.textMuted,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: PLDesign.sectionTitle),
                      const SizedBox(height: 6),
                      Text(subtitle, style: PLDesign.caption),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? Colors.white54 : Colors.white24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
