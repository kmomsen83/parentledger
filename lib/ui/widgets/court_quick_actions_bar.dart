import 'package:flutter/material.dart';

import '../../design/design.dart';

typedef QuickActionCallback = void Function(String actionId);

/// Large tap targets for stressed-user flows.
class CourtQuickActionsBar extends StatelessWidget {
  const CourtQuickActionsBar({
    super.key,
    required this.onAction,
  });

  final QuickActionCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _chip(context, 'im_here', "I'm here", Icons.place_rounded),
        _chip(context, 'running_late', 'Running late', Icons.schedule_rounded),
        _chip(context, 'add_expense', 'Add expense', Icons.attach_money_rounded),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    String id,
    String label,
    IconData icon,
  ) {
    return Material(
      color: PLDesign.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onAction(id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: PLDesign.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: PLDesign.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
