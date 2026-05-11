import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';

class TrustEvidenceStatusScreen extends StatelessWidget {
  const TrustEvidenceStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final linkedCase = session.caseId != null;
    final premium =
        session.isAttorney || session.unlockedParentPremiumFeatures;
    final members = session.memberIds.length;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('trustEvidence')),
        backgroundColor: PLDesign.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _statusCard(
            context.tTone('trustCaseLinkageTitle'),
            linkedCase
                ? context.tTone('trustCaseLinkageStatusConnected')
                : context.tTone('trustCaseLinkageStatusNotConnected'),
            linkedCase
                ? context.tTone('trustCaseLinkageDetailConnected')
                : context.tTone('trustCaseLinkageDetailNotConnected'),
            linkedCase ? PLDesign.success : PLDesign.warning,
          ),
          const SizedBox(height: 12),
          _statusCard(
            context.tTone('trustRecordIntegrityTitle'),
            context.tTone('trustRecordIntegrityStatus'),
            context.tTone('trustRecordIntegrityDetail'),
            PLDesign.info,
          ),
          const SizedBox(height: 12),
          _statusCard(
            context.tTone('trustParticipantsTitle'),
            '$members member${members == 1 ? '' : 's'}',
            context.tTone('trustParticipantsDetail'),
            PLDesign.primary,
          ),
          const SizedBox(height: 12),
          _statusCard(
            context.tTone('trustExportReadinessTitle'),
            premium
                ? context.tTone('trustExportReadinessStatusFull')
                : context.tTone('trustExportReadinessStatusLimited'),
            premium
                ? context.tTone('trustExportReadinessDetailFull')
                : context.tTone('trustExportReadinessDetailLimited'),
            premium ? PLDesign.success : PLDesign.warning,
          ),
          const SizedBox(height: 18),
          Text(
            context.tTone('parentledgerIsADocumentationPlatform'),
            style: PLDesign.caption.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(
    String title,
    String status,
    String detail,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: PLDesign.sectionTitle),
              const Spacer(),
              Text(
                status,
                style: PLDesign.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(detail, style: PLDesign.caption.copyWith(height: 1.35)),
        ],
      ),
    );
  }
}
