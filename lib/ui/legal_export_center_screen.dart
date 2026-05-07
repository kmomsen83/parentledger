import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:parentledger/design/design.dart';
import 'package:parentledger/providers/case_context.dart';
import 'package:parentledger/services/case_switcher_service.dart';
import 'package:parentledger/services/counsel_access_policy.dart';
import 'package:parentledger/services/legal_export_service.dart';
import 'package:parentledger/ui/legal_export_preview_screen.dart';
import 'package:parentledger/ui/widgets/premium_upgrade_sheet.dart';
import 'package:parentledger/ui/widgets/trust_elements.dart';

class LegalExportCenterScreen extends StatefulWidget {
  const LegalExportCenterScreen({super.key});

  @override
  State<LegalExportCenterScreen> createState() =>
      _LegalExportCenterScreenState();
}

class _LegalExportCenterScreenState extends State<LegalExportCenterScreen> {
  String? loadingType;

  /// ================================
  /// GENERATE EXPORT
  /// ================================
  Future<void> generate(String type, CaseContext session) async {
    if (loadingType != null) return;
    if (!session.isAttorney && !session.unlockedParentPremiumFeatures) {
      await showPremiumUpgradeSheet(
        context,
        feature: DashboardPremiumFeature.complianceReports,
      );
      return;
    }

    final watermarked = session.isAttorney;

    final caseId = session.isAttorney
        ? (context.read<CaseSwitcherService>().selectedCaseId ?? session.caseId)
        : session.caseId;
    if (caseId == null || caseId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No case selected. Open a case and try again.'),
          ),
        );
      }
      return;
    }

    if (session.isAttorney) {
      final wait = await CounselAccessPolicy.exportCooldownRemaining();
      if (wait != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait a moment before exporting again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => loadingType = type);

    try {
      final doc = await LegalExportService().generate(type, caseId: caseId);

      if (!mounted) return;

      if (session.isAttorney) {
        await CounselAccessPolicy.recordExportCompleted();
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              LegalExportPreviewScreen(document: doc, watermarked: watermarked),
        ),
      );
    } catch (_) {
      if (kDebugMode) {
        debugPrint("Export failed");
      }

      if (!mounted) return;

      showError('Could not generate export. Try again.', type, session);
    }

    if (!mounted) return;
    setState(() => loadingType = null);
  }

  /// ================================
  /// ERROR UI (RETRY SUPPORT)
  /// ================================
  void showError(String message, String type, CaseContext session) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Export Failed"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              generate(type, session);
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  /// ================================
  /// TILE
  /// ================================
  Widget tile({
    required IconData icon,
    required String title,
    required String desc,
    required String type,
    required CaseContext session,
  }) {
    final isLoading = loadingType == type;

    return GestureDetector(
      onTap: isLoading ? null : () => generate(type, session),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: loadingType != null && !isLoading ? 0.5 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: PLDesign.card,
            borderRadius: PLDesign.r20,
            border: Border.all(color: PLDesign.border),
            boxShadow: PLDesign.softShadow,
          ),
          child: Row(
            children: [
              Icon(icon, color: PLDesign.primary),
              const SizedBox(width: 12),

              /// TEXT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PLDesign.sectionTitle),
                    const SizedBox(height: 4),
                    Text(desc, style: PLDesign.caption),
                  ],
                ),
              ),

              /// LOADING OR ARROW
              isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  /// ================================
  /// BUILD
  /// ================================
  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Case export"),
      ),
      body: Stack(
        children: [
          /// MAIN CONTENT
          PLDesign.screen(
            title: "Export your case",
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const TrustNote(
                    text:
                        'Generate structured reports for mediation, legal review, or personal records.',
                  ),
                  const SizedBox(height: 8),
                  const HelperText(
                    text:
                        'Exports include time-stamped messages, activity, and expenses.',
                    icon: Icons.verified_user_outlined,
                  ),
                  const SizedBox(height: 18),

                  /// ================================
                  /// EXPORT OPTIONS
                  /// ================================

                  tile(
                    icon: Icons.picture_as_pdf,
                    title: "Full Case Report",
                    desc: "Complete documented history for court",
                    type: "full",
                    session: session,
                  ),

                  tile(
                    icon: Icons.timeline,
                    title: "Timeline Report",
                    desc: "Chronological custody & communication log",
                    type: "timeline",
                    session: session,
                  ),

                  tile(
                    icon: Icons.receipt_long,
                    title: "Expense Report",
                    desc: "Shared expenses and balances",
                    type: "expenses",
                    session: session,
                  ),

                  tile(
                    icon: Icons.warning_amber_rounded,
                    title: "Violation Report",
                    desc: "Missed exchanges and items to review",
                    type: "violations",
                    session: session,
                  ),
                ],
              ),
            ),
          ),

          /// ================================
          /// GLOBAL LOADING OVERLAY
          /// ================================
          if (loadingType != null)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
