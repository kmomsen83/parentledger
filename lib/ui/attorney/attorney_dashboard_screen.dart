import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../services/attorney_case_status_service.dart';
import '../../services/case_switcher_service.dart';
import '../case_unified_timeline_screen.dart';
import '../enter_invite_code_screen.dart';

class AttorneyDashboardScreen extends StatelessWidget {
  const AttorneyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final switcher = context.watch<CaseSwitcherService>();
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Your Cases'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EnterInviteCodeScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Case / Join via Invite Code'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('cases')
            .orderBy('linkedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          final rows = snap.data?.docs ?? [];
          if (rows.isEmpty) {
            return const Center(child: Text('No assigned cases yet.'));
          }
          final caseIds =
              rows.map((r) => (r.data()['caseId'] ?? r.id).toString()).toList();
          return FutureBuilder<List<_AttorneyCaseVM>>(
            future: _loadModels(caseIds),
            builder: (context, modelSnap) {
              final models = modelSnap.data ?? const <_AttorneyCaseVM>[];
              models.sort((a, b) {
                if (a.issueCount != b.issueCount) {
                  return b.issueCount.compareTo(a.issueCount);
                }
                final aTs = a.lastActivity?.millisecondsSinceEpoch ?? 0;
                final bTs = b.lastActivity?.millisecondsSinceEpoch ?? 0;
                return bTs.compareTo(aTs);
              });
              final totalIssues =
                  models.fold<int>(0, (total, m) => total + m.issueCount);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  _HeaderStats(
                    caseCount: models.length,
                    totalIssues: totalIssues,
                    caseIds: caseIds,
                    selectedCaseId: switcher.selectedCaseId,
                    onSelectCase: switcher.hasMultipleCases
                        ? (v) => switcher.selectCase(v)
                        : null,
                  ),
                  const SizedBox(height: 10),
                  ...models.map((m) => _CaseCard(model: m)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<List<_AttorneyCaseVM>> _loadModels(List<String> caseIds) async {
    final db = FirebaseFirestore.instance;
    final out = <_AttorneyCaseVM>[];
    for (final caseId in caseIds) {
      final caseSnap = await db.collection('cases').doc(caseId).get();
      final data = caseSnap.data() ?? const <String, dynamic>{};
      final status = await AttorneyCaseStatusService.compute(caseId);
      final childrenCount = await db
          .collection('cases')
          .doc(caseId)
          .collection('children')
          .count()
          .get()
          .then((v) => v.count ?? 0);
      final familyName =
          (data['name'] ?? data['title'] ?? 'Case $caseId').toString();
      final score = (data['complianceScore'] is num)
          ? (data['complianceScore'] as num).toDouble()
          : 75.0;
      out.add(
        _AttorneyCaseVM(
          caseId: caseId,
          familyName: familyName,
          childrenCount: childrenCount,
          complianceScore: score,
          issueCount: status.issueCount,
          lastActivity: status.lastActivityAt,
        ),
      );
    }
    return out;
  }
}

class _HeaderStats extends StatelessWidget {
  const _HeaderStats({
    required this.caseCount,
    required this.totalIssues,
    required this.caseIds,
    required this.selectedCaseId,
    required this.onSelectCase,
  });

  final int caseCount;
  final int totalIssues;
  final List<String> caseIds;
  final String? selectedCaseId;
  final void Function(String)? onSelectCase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PLDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active cases: $caseCount',
              style: PLDesign.sectionTitle.copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text('Flagged issues: $totalIssues', style: PLDesign.caption),
          if (onSelectCase != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedCaseId ?? caseIds.first,
              items: caseIds
                  .map((id) => DropdownMenuItem(
                      value: id, child: Text('Switch Case: $id')))
                  .toList(),
              onChanged: (v) {
                if (v != null) onSelectCase!(v);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.model});

  final _AttorneyCaseVM model;

  @override
  Widget build(BuildContext context) {
    final severityColor = model.complianceScore >= 80
        ? Colors.green
        : model.complianceScore >= 60
            ? Colors.orange
            : Colors.red;
    final last = model.lastActivity != null
        ? DateFormat.yMMMd().add_jm().format(model.lastActivity!.toLocal())
        : 'No activity';
    final badge = model.issueCount > 0
        ? '🔴 Violations'
        : (model.complianceScore < 70 ? '🟡 Expenses' : '🟢 Clean');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(model.familyName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text('Children: ${model.childrenCount}'),
            Text('Compliance: ${model.complianceScore.toStringAsFixed(0)}',
                style: TextStyle(
                    color: severityColor, fontWeight: FontWeight.w700)),
            Text('Active issues: ${model.issueCount}'),
            Text('Last activity: $last'),
            const SizedBox(height: 4),
            Text(badge),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CaseUnifiedTimelineScreen(caseId: model.caseId),
            ),
          );
        },
      ),
    );
  }
}

class _AttorneyCaseVM {
  const _AttorneyCaseVM({
    required this.caseId,
    required this.familyName,
    required this.childrenCount,
    required this.complianceScore,
    required this.issueCount,
    required this.lastActivity,
  });

  final String caseId;
  final String familyName;
  final int childrenCount;
  final double complianceScore;
  final int issueCount;
  final DateTime? lastActivity;
}
