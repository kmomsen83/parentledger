import 'package:flutter/material.dart';

import '../../design/design.dart';

class HelperText extends StatelessWidget {
  const HelperText({
    super.key,
    required this.text,
    this.icon,
  });

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon ?? Icons.info_outline, size: 16, color: PLDesign.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: PLDesign.caption.copyWith(
              color: PLDesign.textMuted,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class TrustNote extends StatelessWidget {
  const TrustNote({
    super.key,
    required this.text,
    this.icon = Icons.lock_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x26C89B3C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x55C89B3C)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFC89B3C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: PLDesign.caption.copyWith(
                color: PLDesign.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageTrustBanner extends StatelessWidget {
  const MessageTrustBanner({
    super.key,
    required this.minimized,
    required this.onToggle,
  });

  final bool minimized;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x1FC89B3C),
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFFC89B3C)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  minimized
                      ? 'Messages are securely recorded for your case.'
                      : 'Messages are time-stamped, stored securely, and can be used for legal documentation.',
                  style: PLDesign.caption.copyWith(
                    color: PLDesign.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
              Icon(
                minimized ? Icons.expand_more : Icons.expand_less,
                size: 18,
                color: PLDesign.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

