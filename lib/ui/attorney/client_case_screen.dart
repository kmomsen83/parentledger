import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../providers/case_context.dart';
import '../../services/attorney_case_bundle_pdf_service.dart';
import '../../services/attorney_case_access_service.dart';
import '../../services/attorney_case_priority.dart';
import '../../services/attorney_case_status_service.dart';
import '../../services/case_switcher_service.dart';
import '../../services/counsel_access_policy.dart';
import '../calendar_month_view_screen.dart';
import '../case_insights_screen.dart';
import '../case_unified_timeline_screen.dart';
import '../compliance_report_screen.dart';
import '../conversation_thread_screen.dart';
import '../documents_library_screen.dart';
import '../expenses_list_screen.dart';
import '../legal_export_center_screen.dart';
import '../timeline_violations_screen.dart';
import 'attorney_export_case_sheet.dart';
import 'attorney_priority_badge.dart';

/// Single-client counsel workspace: tabbed timeline, messages, documents, insights.
///
/// [clientId] is the Firestore case id (`cases/{clientId}`). All queries are scoped to it.
class ClientCaseScreen extends StatefulWidget {
  const ClientCaseScreen({
    super.key,
    required this.clientId,
    this.clientName,
    this.caseStatusLabel,
  });

  /// Case / matter id — must match `users/{attorneyUid}/cases` link.
  final String clientId;

  final String? clientName;
  final String? caseStatusLabel;

  @override
  State<ClientCaseScreen> createState() => _ClientCaseScreenState();
}

class _ClientCaseScreenState extends State<ClientCaseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CaseSwitcherService>().selectCase(widget.clientId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _title {
    final n = widget.clientName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Client matter';
  }

  Color _statusColor(String? label) {
    switch (label) {
      case 'Active':
        return PLDesign.success;
      case 'Pending':
        return PLDesign.warning;
      case 'Closed':
        return PLDesign.textMuted;
      default:
        return PLDesign.info;
    }
  }

  Future<void> _exportCaseBundle() async {
    final session = context.read<CaseContext>();
    if (session.isAttorney) {
      final wait = await CounselAccessPolicy.exportCooldownRemaining();
      if (wait != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please wait a moment before exporting again.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: PLDesign.surface,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: PLDesign.surface,
          content: Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  'Building case bundle…',
                  style: PLDesign.body.copyWith(color: PLDesign.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      final bytes =
          await AttorneyCaseBundlePdfService.buildPdfBytes(widget.clientId);
      if (session.isAttorney) {
        await CounselAccessPolicy.recordExportCompleted();
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      final filename = 'case_bundle_${widget.clientId}.pdf';
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: PLDesign.surface,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined,
                    color: PLDesign.primary),
                title: const Text('Preview & print'),
                subtitle: Text(
                  'Print or save as PDF',
                  style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Printing.layoutPdf(
                    onLayout: (format) async => bytes,
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.share_rounded, color: PLDesign.primary),
                title: const Text('Share PDF'),
                subtitle: Text(
                  'Email or another app',
                  style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Printing.sharePdf(bytes: bytes, filename: filename);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: PLDesign.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openExportCenter() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const LegalExportCenterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in required.')),
      );
    }

    return FutureBuilder<bool>(
      future: AttorneyCaseAccessService.attorneyHasAccess(
        attorneyUid: uid,
        caseId: widget.clientId,
      ),
      builder: (context, accessSnap) {
        if (accessSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: PLDesign.background,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xff152238), Color(0xff0c1220)],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: PLDesign.primary),
              ),
            ),
          );
        }
        if (accessSnap.data != true) {
          return Scaffold(
            backgroundColor: PLDesign.background,
            appBar: AppBar(
              backgroundColor: PLDesign.surface,
              foregroundColor: PLDesign.textPrimary,
              title: const Text('Access denied'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'You do not have access to this matter, or it is no longer linked to your account.',
                  style: PLDesign.body.copyWith(height: 1.45),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final statusLabel = widget.caseStatusLabel ?? 'Linked';
        final stColor = _statusColor(widget.caseStatusLabel);

        return Scaffold(
          backgroundColor: PLDesign.background,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: PLDesign.surface,
            foregroundColor: PLDesign.textPrimary,
            title: const SizedBox.shrink(),
            leading: const BackButton(),
            actions: [
              TextButton.icon(
                onPressed: () => showAttorneyExportCaseSheet(
                  context,
                  caseId: widget.clientId,
                ),
                icon: const Icon(Icons.file_download_outlined, size: 20),
                label: const Text('Export Case'),
                style: TextButton.styleFrom(
                  foregroundColor: PLDesign.primary,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More exports',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) {
                  if (v == 'bundle') _exportCaseBundle();
                  if (v == 'center') _openExportCenter();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem<String>(
                    value: 'bundle',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined,
                            size: 20, color: PLDesign.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Quick case bundle',
                            style: PLDesign.body.copyWith(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'center',
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 20, color: PLDesign.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Export center',
                            style: PLDesign.body.copyWith(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: PLDesign.primary,
              labelColor: PLDesign.textPrimary,
              unselectedLabelColor: PLDesign.textMuted,
              labelStyle: PLDesign.caption.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Timeline'),
                Tab(text: 'Messages'),
                Tab(text: 'Documents'),
                Tab(text: 'Insights'),
                Tab(text: 'Matter'),
              ],
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: PLDesign.card,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _title,
                              style: PLDesign.heroTitle.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                          StreamBuilder<AttorneyCaseStatus>(
                            stream: AttorneyCaseStatusService.watch(
                                widget.clientId),
                            builder: (context, stSnap) {
                              final p = stSnap.data?.priority ??
                                  AttorneyCasePriority.stable;
                              return AttorneyPriorityBadge(
                                priority: p,
                                compact: true,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: stColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: stColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: PLDesign.caption.copyWith(
                                color: stColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PLDesign.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: PLDesign.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              'Attorney Access',
                              style: PLDesign.caption.copyWith(
                                color: PLDesign.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    CaseUnifiedTimelineScreen(
                      caseId: widget.clientId,
                      embedInParent: true,
                    ),
                    ConversationThreadScreen(
                      title: 'Messages',
                      caseId: widget.clientId,
                      embedInParent: true,
                    ),
                    DocumentsLibraryScreen(
                      caseId: widget.clientId,
                      embedInParent: true,
                    ),
                    _ClientInsightsTab(caseId: widget.clientId),
                    _AttorneyMatterToolsTab(caseId: widget.clientId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttorneyMatterToolsTab extends StatelessWidget {
  const _AttorneyMatterToolsTab({required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Text(
          'Case workspace',
          style: PLDesign.sectionTitle.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          'Open matter-scoped tools. Exports use your saved attorney branding.',
          style: PLDesign.caption.copyWith(
            color: PLDesign.textMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        _MatterToolRow(
          icon: Icons.calendar_month_rounded,
          title: 'Calendar',
          subtitle: 'Custody schedule & events',
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const CalendarMonthViewScreen(),
            ),
          ),
        ),
        _MatterToolRow(
          icon: Icons.receipt_long_rounded,
          title: 'Expenses & reimbursements',
          subtitle: 'Shared ledger for this matter',
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ExpensesListScreen(),
            ),
          ),
        ),
        _MatterToolRow(
          icon: Icons.assignment_turned_in_outlined,
          title: 'Compliance & reports',
          subtitle: 'Structured matter summary',
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ComplianceReportScreen(),
            ),
          ),
        ),
        _MatterToolRow(
          icon: Icons.gavel_rounded,
          title: 'Timeline violations',
          subtitle: 'Review flagged schedule issues',
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => TimelineViolationsScreen(caseId: caseId),
            ),
          ),
        ),
        _MatterToolRow(
          icon: Icons.folder_special_outlined,
          title: 'Court export center',
          subtitle: 'Bundles & legal exports',
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const LegalExportCenterScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

class _MatterToolRow extends StatelessWidget {
  const _MatterToolRow({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PLDesign.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: PLDesign.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: PLDesign.sectionTitle.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: PLDesign.caption.copyWith(height: 1.25),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: PLDesign.textMuted.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientInsightsTab extends StatelessWidget {
  const _ClientInsightsTab({required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<AttorneyCaseStatus>(
          stream: AttorneyCaseStatusService.watch(caseId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            final s = snap.data!;
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _insightChip(
                      'Health',
                      s.healthScore.round().toString(),
                      PLDesign.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _insightChip(
                      'Missed',
                      '${s.missedExchangeCount}',
                      s.missedExchangeCount > 0
                          ? PLDesign.warning
                          : PLDesign.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _insightChip(
                      'Msg flags',
                      '${s.flaggedMessageCount}',
                      s.flaggedMessageCount > 0
                          ? PLDesign.warning
                          : PLDesign.textMuted,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: CaseInsightsScreen(
            caseId: caseId,
            embedInParent: true,
          ),
        ),
      ],
    );
  }

  Widget _insightChip(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: PLDesign.statNumber.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: PLDesign.caption.copyWith(
              fontSize: 11,
              color: PLDesign.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
