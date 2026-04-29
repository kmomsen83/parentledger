import 'package:flutter/material.dart';

import '../../design/design.dart';

class GuidedStepCard extends StatelessWidget {
  const GuidedStepCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.cta,
    required this.completed,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String cta;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed
              ? PLDesign.success.withValues(alpha: 0.55)
              : PLDesign.border,
        ),
        boxShadow: completed ? PLDesign.softShadow : const [],
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : icon,
            color: completed ? PLDesign.success : PLDesign.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PLDesign.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(description, style: PLDesign.caption),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: completed ? null : onTap,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            child: Text(completed ? 'Done' : cta),
          ),
        ],
      ),
    );
  }
}

