import 'package:flutter/material.dart';

import 'client_case_screen.dart';

/// Opens [ClientCaseScreen] for a linked matter (backward-compatible name).
class ClientWorkspaceScreen extends StatelessWidget {
  const ClientWorkspaceScreen({
    super.key,
    required this.caseId,
    this.parentNamesLabel,
    this.caseStatusLabel,
  });

  final String caseId;
  final String? parentNamesLabel;
  final String? caseStatusLabel;

  @override
  Widget build(BuildContext context) {
    return ClientCaseScreen(
      clientId: caseId,
      clientName: parentNamesLabel,
      caseStatusLabel: caseStatusLabel,
    );
  }
}
