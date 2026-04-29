import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import 'case_evidence_screen.dart';
import 'case_summary_screen.dart';
import 'case_unified_timeline_screen.dart';
import 'legal_export_center_screen.dart';
import 'messages_inbox_screen.dart';

/// Unified case workspace — all legal workflows revolve around the active case.
class CaseCenterScreen extends StatelessWidget {
  const CaseCenterScreen({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('caseCenter')),
        elevation: 0,
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
      ),
      body: caseId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Link a custody case in your workspace to use the Case Center.',
                  textAlign: TextAlign.center,
                  style: PLDesign.body.copyWith(height: 1.4),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Your case file',
                  style: PLDesign.pageTitle.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  'Messages, timeline, evidence, summaries, and exports — one place.',
                  style: PLDesign.caption.copyWith(height: 1.35),
                ),
                const SizedBox(height: 28),
                _SectionLabel('Communications'),
                _CaseTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Messages',
                  subtitle:
                      'All threads — titles, last message, time, unread',
                  onTap: () => _go(context, const MessagesInboxScreen()),
                ),
                const SizedBox(height: 20),
                _SectionLabel('Record'),
                _CaseTile(
                  icon: Icons.timeline_rounded,
                  title: 'Timeline',
                  subtitle: 'Messages, exchanges, expenses, violations',
                  onTap: () => _go(
                    context,
                    CaseUnifiedTimelineScreen(caseId: caseId),
                  ),
                ),
                const SizedBox(height: 12),
                _CaseTile(
                  icon: Icons.folder_special_rounded,
                  title: 'Evidence',
                  subtitle: 'Documents, voice, transcriptions',
                  onTap: () => _go(context, const CaseEvidenceScreen()),
                ),
                const SizedBox(height: 20),
                _SectionLabel('Analysis'),
                _CaseTile(
                  icon: Icons.summarize_rounded,
                  title: 'Case summary (AI)',
                  subtitle: 'Court-ready summaries — filter by date range',
                  onTap: () => _go(context, const CaseSummaryScreen()),
                ),
                const SizedBox(height: 20),
                _SectionLabel('Export'),
                _CaseTile(
                  icon: Icons.share_rounded,
                  title: 'Export',
                  subtitle: 'Full case, timeline, expenses, violations',
                  onTap: () => _go(
                    context,
                    const LegalExportCenterScreen(),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: PLDesign.caption.copyWith(
          letterSpacing: 1.1,
          fontWeight: FontWeight.w800,
          color: PLDesign.textMuted,
        ),
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PLDesign.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PLDesign.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: PLDesign.primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PLDesign.sectionTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: PLDesign.caption.copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PLDesign.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
