import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/case_context.dart';
import '../../services/case_switcher_service.dart';

class AttorneyCaseSwitcher extends StatelessWidget {
  const AttorneyCaseSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final switcher = context.watch<CaseSwitcherService>();
    if (!session.isAttorney || !switcher.hasMultipleCases) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      tooltip: 'Switch case',
      icon: const Icon(Icons.swap_horiz),
      onSelected: (value) => switcher.selectCase(value),
      itemBuilder: (context) => switcher.cases
          .map(
            (c) => PopupMenuItem<String>(
              value: c.caseId,
              child: Text(
                c.caseId == switcher.selectedCaseId
                    ? '✓ ${c.caseId}'
                    : c.caseId,
              ),
            ),
          )
          .toList(),
    );
  }
}
