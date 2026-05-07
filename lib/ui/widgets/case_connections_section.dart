import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../providers/case_context.dart';
import '../../services/case_connections_service.dart';
import '../../services/firestore_fields.dart';

/// Card-based list of co-parents and attorneys linked to the signed-in user's case.
class CaseConnectionsSection extends StatelessWidget {
  const CaseConnectionsSection({
    super.key,
    required this.caseId,
    required this.canManageConnections,
  });

  final String caseId;
  final bool canManageConnections;

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('cases')
          .doc(caseId)
          .snapshots(),
      builder: (context, caseSnap) {
        if (!caseSnap.hasData || !caseSnap.data!.exists) {
          return const SizedBox.shrink();
        }
        final memberIds =
            FirestoreFields.readCaseMemberIds(caseSnap.data!.data() ?? {});

        return FutureBuilder<List<CaseConnectionRow>>(
          key: ObjectKey('$caseId-${memberIds.join(",")}'),
          future: CaseConnectionsService.buildRows(
            caseId: caseId,
            myUid: myUid,
            memberIdsFromCase: memberIds,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Could not load connections.',
                  style: PLDesign.caption.copyWith(color: PLDesign.danger),
                ),
              );
            }
            final rows = snap.data ?? [];
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'No one else is linked to this case yet. Invite your co-parent or counsel below.',
                  style: PLDesign.caption.copyWith(
                    color: PLDesign.textMuted,
                    height: 1.35,
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'People with access to this case',
                  style: PLDesign.caption.copyWith(
                    color: PLDesign.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                ...rows.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ConnectionCard(
                      row: r,
                      canManageConnections: canManageConnections,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.row,
    required this.canManageConnections,
  });

  final CaseConnectionRow row;
  final bool canManageConnections;

  Future<void> _confirmAndAct(BuildContext context) async {
    final isAttorney = row.kind == CaseConnectionKind.attorney;
    final title =
        isAttorney ? 'Revoke attorney access?' : 'Remove co-parent link?';
    final body = isAttorney
        ? '${row.displayName} will lose read-only access to this case. You can invite them again later.'
        : '${row.displayName} will be removed from this shared case and given their own separate workspace. Shared history stays on your case.';

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(
          body,
          style: const TextStyle(color: Colors.white70, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: PLDesign.danger),
            child: Text(isAttorney ? 'Revoke access' : 'Remove connection'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;

    try {
      if (isAttorney) {
        await CaseConnectionsService.revokeAttorney(row.userId);
      } else {
        await CaseConnectionsService.removeCoParent(row.userId);
      }
      if (!context.mounted) return;
      await context.read<CaseContext>().retrySessionLoading();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAttorney
                ? 'Attorney access revoked.'
                : 'Co-parent removed from this case.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      final msg = CaseConnectionsService.mapFunctionsError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAttorney = row.kind == CaseConnectionKind.attorney;
    final badgeColor =
        isAttorney ? const Color(0xff6366f1) : const Color(0xff22c55e);
    final badgeLabel = isAttorney ? 'Attorney' : 'Co-Parent';
    final statusLabel =
        isAttorney ? 'Read-only access' : 'Connected';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PLDesign.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PLDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: badgeColor.withValues(alpha: 0.2),
                foregroundColor: badgeColor,
                child: Icon(
                  isAttorney ? Icons.gavel_rounded : Icons.people_rounded,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.displayName,
                      style: PLDesign.sectionTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            badgeLabel,
                            style: PLDesign.caption.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        Text(
                          statusLabel,
                          style: PLDesign.caption.copyWith(
                            color: PLDesign.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canManageConnections) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmAndAct(context),
                icon: Icon(
                  isAttorney ? Icons.link_off_rounded : Icons.person_off_rounded,
                  size: 18,
                  color: PLDesign.danger,
                ),
                label: Text(
                  isAttorney ? 'Revoke access' : 'Remove connection',
                  style: TextStyle(
                    color: PLDesign.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
