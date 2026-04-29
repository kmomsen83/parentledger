import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import 'documents_library_screen.dart';
import 'legal_transcription_screen.dart';

/// Evidence hub: documents + voice / transcription under the case.
class CaseEvidenceScreen extends StatelessWidget {
  const CaseEvidenceScreen({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('evidence')),
        elevation: 0,
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
      ),
      body: caseId == null
          ? Center(child: Text(context.tTone('noCaseLinked')))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Build your record',
                  style: PLDesign.pageTitle.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload court orders and agreements, capture voice notes, and keep '
                  'transcriptions tied to this case.',
                  style: PLDesign.caption.copyWith(height: 1.35),
                ),
                const SizedBox(height: 24),
                _EvidenceTile(
                  icon: Icons.description_outlined,
                  title: 'Documents',
                  subtitle: 'PDFs, images, agreements, court orders',
                  onTap: () => _go(context, const DocumentsLibraryScreen()),
                ),
                const SizedBox(height: 12),
                _EvidenceTile(
                  icon: Icons.mic_none_rounded,
                  title: 'Voice & transcription',
                  subtitle: 'Record or dictate for the legal log',
                  onTap: () => _go(
                    context,
                    LegalTranscriptionScreen(caseId: caseId),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PLDesign.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 28, color: PLDesign.info),
              const SizedBox(width: 16),
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
              const Icon(Icons.chevron_right, color: PLDesign.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
