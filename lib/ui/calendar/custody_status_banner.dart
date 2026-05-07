import 'package:flutter/material.dart';

import '../../design/design.dart';
import '../../services/calendar_engine_service.dart';

/// Pin summary line for custody / exchange awareness on calendar surfaces.
class CustodyStatusBanner extends StatelessWidget {
  const CustodyStatusBanner({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustodySnapshot?>(
      future: CalendarEngineService.getCurrentCustody(caseId: caseId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 8);
        }
        final c = snap.data!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: PLDesign.surface,
            border: Border.all(color: PLDesign.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            c.label,
            style: PLDesign.body.copyWith(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}
