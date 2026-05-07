import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../providers/case_context.dart';
import '../../services/attorney_export_case_report_pdf_service.dart';
import '../../services/counsel_access_policy.dart';

Future<void> showAttorneyExportCaseSheet(
  BuildContext context, {
  required String caseId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => AttorneyExportCaseSheet(
      caseId: caseId,
      hostContext: context,
    ),
  );
}

class AttorneyExportCaseSheet extends StatefulWidget {
  const AttorneyExportCaseSheet({
    super.key,
    required this.caseId,
    required this.hostContext,
  });

  final String caseId;

  /// Caller context (still mounted after the sheet closes).
  final BuildContext hostContext;

  @override
  State<AttorneyExportCaseSheet> createState() => _AttorneyExportCaseSheetState();
}

class _AttorneyExportCaseSheetState extends State<AttorneyExportCaseSheet> {
  late DateTime _start;
  late DateTime _end;
  bool _summary = true;
  bool _timeline = true;
  bool _messages = true;
  bool _documents = true;

  static DateTime _stripTime(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final now = _stripTime(DateTime.now());
    _end = now;
    _start = now.subtract(const Duration(days: 90));
  }

  Future<void> _pickRange() async {
    final clock = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(clock.year - 5),
      lastDate: DateTime(clock.year + 1),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.dark(
              surface: PLDesign.surface,
              primary: PLDesign.primary,
              onPrimary: Colors.white,
              onSurface: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() {
      _start = _stripTime(picked.start);
      _end = _stripTime(picked.end);
    });
  }

  Future<void> _generate() async {
    if (!mounted) return;
    final host = widget.hostContext;
    final sheetNav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(host);
    final session = context.read<CaseContext>();

    if (!_summary && !_timeline && !_messages && !_documents) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Choose at least one section.')),
      );
      return;
    }
    if (_end.isBefore(_start)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('End date must be on or after start date.')),
      );
      return;
    }

    if (session.isAttorney) {
      final wait = await CounselAccessPolicy.exportCooldownRemaining();
      if (!host.mounted) return;
      if (wait != null) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Please wait a moment before exporting again.'),
            backgroundColor: PLDesign.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final config = AttorneyExportCaseReportConfig(
      rangeStartInclusive: _start,
      rangeEndInclusive: _end,
      includeSummary: _summary,
      includeTimeline: _timeline,
      includeMessages: _messages,
      includeDocuments: _documents,
    );

    sheetNav.pop();

    if (!host.mounted) return;
    showDialog<void>(
      context: host,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: PLDesign.surface,
          content: Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  'Generating report…',
                  style: PLDesign.body.copyWith(color: PLDesign.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final bytes =
          await AttorneyExportCaseReportPdfService.buildPdfBytes(
        caseId: widget.caseId,
        config: config,
      );
      if (session.isAttorney) {
        await CounselAccessPolicy.recordExportCompleted();
      }
      if (!host.mounted) return;
      Navigator.of(host).pop();

      final fname =
          'case_report_${widget.caseId}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      await showModalBottomSheet<void>(
        context: host,
        backgroundColor: PLDesign.surface,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Report ready',
                  style: PLDesign.sectionTitle.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
              ListTile(
                leading: Icon(Icons.visibility_rounded, color: PLDesign.primary),
                title: const Text('Preview / print'),
                subtitle: Text(
                  'Open print dialog (save as PDF on most devices)',
                  style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Printing.layoutPdf(
                    onLayout: (_) async => bytes,
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.share_rounded, color: PLDesign.primary),
                title: const Text('Share PDF'),
                subtitle: Text(
                  'Email, drive, or other apps',
                  style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Printing.sharePdf(bytes: bytes, filename: fname);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    } catch (e) {
      if (host.mounted) {
        Navigator.of(host).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not generate report: $e'),
            backgroundColor: PLDesign.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rangeStr =
        '${DateFormat.yMMMd().format(_start)} → ${DateFormat.yMMMd().format(_end)}';

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.94,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: PLDesign.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: PLDesign.border),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Export Case',
              style: PLDesign.sectionTitle.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Build a court-style PDF for this matter. All content is filtered by case and the dates you choose.',
              style: PLDesign.body.copyWith(
                color: PLDesign.textMuted,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Date range',
              style: PLDesign.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_rounded, size: 20),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  rangeStr,
                  style: PLDesign.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Sections',
              style: PLDesign.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Include Summary', style: PLDesign.body),
              subtitle: Text(
                'Metrics + neutral narrative (AI-assisted)',
                style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
              ),
              value: _summary,
              activeTrackColor: PLDesign.primary.withValues(alpha: 0.5),
              onChanged: (v) => setState(() => _summary = v),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Include Timeline', style: PLDesign.body),
              subtitle: Text(
                'Case ledger events in range',
                style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
              ),
              value: _timeline,
              activeTrackColor: PLDesign.primary.withValues(alpha: 0.5),
              onChanged: (v) => setState(() => _timeline = v),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Include Messages', style: PLDesign.body),
              subtitle: Text(
                'Primary thread, verbatim',
                style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
              ),
              value: _messages,
              activeTrackColor: PLDesign.primary.withValues(alpha: 0.5),
              onChanged: (v) => setState(() => _messages = v),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Include Documents', style: PLDesign.body),
              subtitle: Text(
                'Uploads indexed in range (names & timestamps)',
                style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
              ),
              value: _documents,
              activeTrackColor: PLDesign.primary.withValues(alpha: 0.5),
              onChanged: (v) => setState(() => _documents = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _generate,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: PLDesign.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Generate Report',
                style: PLDesign.buttonText,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
