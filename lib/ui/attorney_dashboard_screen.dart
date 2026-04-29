import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';
import '../services/attorney_case_status_service.dart';
import '../services/legal_summary_service.dart';
import 'case_unified_timeline_screen.dart';
import 'conversation_thread_screen.dart';
import 'documents_library_screen.dart';
import 'legal_summary_detail_screen.dart';

/// Attorney multi-case portal.
class AttorneyDashboardScreen extends StatefulWidget {
  const AttorneyDashboardScreen({super.key});

  @override
  State<AttorneyDashboardScreen> createState() =>
      _AttorneyDashboardScreenState();
}

class _AttorneyDashboardScreenState extends State<AttorneyDashboardScreen> {
  String? _selectedCaseId;

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _generateBrief(BuildContext context, String caseId) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(context.tTone('compilingAttorneyBrief')),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final id = await LegalSummaryService.generateAttorneyCourtSummaryAndStore(
        caseId: caseId,
        messageLimit: 100,
      );
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LegalSummaryDetailScreen(
            caseId: caseId,
            summaryId: id,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate brief: $e')),
      );
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return 'No activity yet';
    final d = DateTime.now().difference(ts.toDate());
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat.yMMMd().format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Your Cases'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: PLDesign.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'ATTORNEY',
                style: PLDesign.caption.copyWith(
                  color: PLDesign.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('cases')
                  .orderBy('linkedAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                final rows = snap.data?.docs ?? [];
                if (rows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'No cases assigned yet. Ask a firm admin to link your account.',
                        style: PLDesign.body.copyWith(height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final caseIds = rows
                    .map((r) => (r.data()['caseId'] ?? r.id).toString())
                    .toList();
                final filtered = _selectedCaseId == null
                    ? rows
                    : rows
                        .where((r) =>
                            (r.data()['caseId'] ?? r.id).toString() ==
                            _selectedCaseId)
                        .toList();

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  itemCount: filtered.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Container(
                        decoration: BoxDecoration(
                          color: PLDesign.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PLDesign.border),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _selectedCaseId,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Switch Case: All assigned cases'),
                              ),
                              ...caseIds.map(
                                (id) => DropdownMenuItem<String?>(
                                  value: id,
                                  child: Text('Switch Case: $id'),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedCaseId = value),
                          ),
                        ),
                      );
                    }
                    final row = filtered[i - 1];
                    final caseId = (row.data()['caseId'] ?? row.id).toString();
                    return _AttorneyCaseCard(
                      caseId: caseId,
                      onOpenMessages: () => _go(
                        context,
                        ConversationThreadScreen(
                            title: 'All messages', caseId: caseId),
                      ),
                      onOpenTimeline: () => _go(
                          context, CaseUnifiedTimelineScreen(caseId: caseId)),
                      onOpenExports: () =>
                          _go(context, const DocumentsLibraryScreen()),
                      onGenerateBrief: () => _generateBrief(context, caseId),
                      timeAgo: _timeAgo,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _AttorneyCaseCard extends StatelessWidget {
  const _AttorneyCaseCard({
    required this.caseId,
    required this.onOpenMessages,
    required this.onOpenTimeline,
    required this.onOpenExports,
    required this.onGenerateBrief,
    required this.timeAgo,
  });

  final String caseId;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenExports;
  final VoidCallback onGenerateBrief;
  final String Function(Timestamp?) timeAgo;

  @override
  Widget build(BuildContext context) {
    final caseRef = FirebaseFirestore.instance.collection('cases').doc(caseId);
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: caseRef.get(),
      builder: (context, caseSnap) {
        final caseData = caseSnap.data?.data() ?? <String, dynamic>{};
        final caseName =
            (caseData['name'] ?? caseData['title'] ?? 'Case $caseId')
                .toString();
        final updatedAt = caseData['updatedAt'] as Timestamp?;

        return FutureBuilder<AttorneyCaseStatus>(
          future: AttorneyCaseStatusService.compute(caseId),
          builder: (context, statusSnap) {
            final status = statusSnap.data;
            final needsAttention = status?.needsAttention ?? false;
            final issueCount = status?.issueCount ?? 0;
            final statusLabel = needsAttention ? 'Needs attention' : 'Stable';
            final statusColor =
                needsAttention ? PLDesign.warning : PLDesign.success;
            final activityLabel = status?.lastActivityAt != null
                ? timeAgo(Timestamp.fromDate(status!.lastActivityAt!))
                : timeAgo(updatedAt);

            return Container(
              decoration: BoxDecoration(
                color: PLDesign.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PLDesign.border),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          caseName,
                          style: PLDesign.sectionTitle.copyWith(fontSize: 17),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: PLDesign.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last activity: $activityLabel',
                    style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Issue count: $issueCount',
                    style: PLDesign.caption.copyWith(
                      color: needsAttention
                          ? PLDesign.warning
                          : PLDesign.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onOpenMessages,
                        icon: const Icon(Icons.forum_outlined, size: 18),
                        label: const Text('Messages'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onOpenTimeline,
                        icon: const Icon(Icons.timeline, size: 18),
                        label: const Text('Timeline'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onOpenExports,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Exports'),
                      ),
                      FilledButton.icon(
                        onPressed: onGenerateBrief,
                        icon: const Icon(Icons.account_balance, size: 18),
                        label: const Text('Brief'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
