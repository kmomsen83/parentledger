import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/case_expense_service.dart';
import 'messages_inbox_screen.dart';
import 'pending_expenses_detail_screen.dart';
import 'upcoming_exchanges_list_screen.dart';

class ActionInboxScreen extends StatelessWidget {
  const ActionInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId;
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('actionInbox')),
        backgroundColor: PLDesign.surface,
      ),
      body: caseId == null
          ? Center(
              child: Text(
                'No case linked yet. Complete setup to see action items.',
                style: PLDesign.body,
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _item(
                  context,
                  icon: Icons.forum,
                  title: 'Review recent messages',
                  subtitle: 'Open your case threads and reply quickly.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagesInboxScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _expenseTask(context, caseId),
                const SizedBox(height: 12),
                _item(
                  context,
                  icon: Icons.swap_horiz,
                  title: 'Check upcoming exchanges',
                  subtitle: 'Confirm times and location details before handoff.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UpcomingExchangesListScreen(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _expenseTask(BuildContext context, String caseId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: CaseExpenseService.watchExpenses(caseId),
      builder: (context, snap) {
        var openCount = 0;
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final m = d.data();
            final paid = m['paid'] == true || m['status'] == 'paid';
            if (!paid) openCount++;
          }
        }
        return _item(
          context,
          icon: Icons.attach_money,
          title: 'Resolve pending expenses',
          subtitle: openCount == 0
              ? 'No pending reimbursements right now.'
              : '$openCount pending expense${openCount == 1 ? '' : 's'} need review.',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PendingExpensesDetailScreen()),
          ),
        );
      },
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PLDesign.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PLDesign.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: PLDesign.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PLDesign.sectionTitle.copyWith(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: PLDesign.caption),
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
}
