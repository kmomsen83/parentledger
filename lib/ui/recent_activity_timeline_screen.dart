import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import 'case_unified_timeline_screen.dart';

/// Backwards-compatible route: unified Firestore case timeline.
class RecentActivityTimelineScreen extends StatelessWidget {
  const RecentActivityTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId;
    if (caseId == null) {
      return Scaffold(
        backgroundColor: PLDesign.background,
        appBar: AppBar(
          title: Text(context.tTone('caseTimeline2')),
          backgroundColor: PLDesign.surface,
          foregroundColor: PLDesign.textPrimary,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No case is linked to your profile yet. Complete setup to view the legal timeline.',
              style: PLDesign.body.copyWith(height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return CaseUnifiedTimelineScreen(caseId: caseId);
  }
}
