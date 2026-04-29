import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';

import '../design/design.dart';

/// Shown when `role == attorney` but `users/{uid}.caseId` is not set.
class AttorneyAwaitingCaseScreen extends StatelessWidget {
  const AttorneyAwaitingCaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('counselAccess')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link_off_rounded, size: 56, color: PLDesign.textMuted),
              const SizedBox(height: 20),
              Text(
                'Case not linked',
                style: PLDesign.sectionTitle.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your attorney profile must be associated with a custody case before '
                'you can open the counsel workspace. Ask your administrator to set '
                'your user record’s case assignment.',
                style: PLDesign.body.copyWith(height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
