import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/case_switcher_service.dart';
import '../services/legal_summary_service.dart';
import 'legal_summary_detail_screen.dart';

/// Court-ready communication summary with optional date-range filter.
class CaseSummaryScreen extends StatefulWidget {
  const CaseSummaryScreen({super.key});

  @override
  State<CaseSummaryScreen> createState() => _CaseSummaryScreenState();
}

class _CaseSummaryScreenState extends State<CaseSummaryScreen> {
  DateTimeRange? _range;
  bool _generating = false;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  Future<void> _generate() async {
    final session = context.read<CaseContext>();
    final caseId = session.isAttorney
        ? (context.read<CaseSwitcherService>().selectedCaseId ?? session.caseId)
        : session.caseId;
    if (caseId == null) return;

    setState(() => _generating = true);
    try {
      final id = await LegalSummaryService.generateAndStore(
        caseId: caseId,
        messageLimit: 100,
        rangeStartInclusive: _range?.start,
        rangeEndInclusive: _range?.end,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LegalSummaryDetailScreen(
            caseId: caseId,
            summaryId: id,
          ),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tTone('summarySavedToYourCase'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final switcher = context.watch<CaseSwitcherService>();
    final caseId = session.isAttorney
        ? (switcher.selectedCaseId ?? session.caseId)
        : session.caseId;
    final df = DateFormat.yMMMd();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('caseSummary')),
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
                  'Neutral, court-style summary',
                  style: PLDesign.pageTitle.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pulls from your primary message thread, filtered by the dates you choose. '
                  'Stored under your case legal summaries.',
                  style: PLDesign.caption.copyWith(height: 1.35),
                ),
                const SizedBox(height: 24),
                Material(
                  color: PLDesign.card,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    title: Text(context.tTone('dateRangeOptional')),
                    subtitle: Text(
                      _range == null
                          ? 'All recent messages in scope'
                          : '${df.format(_range!.start)} — ${df.format(_range!.end)}',
                    ),
                    trailing: const Icon(Icons.date_range_rounded),
                    onTap: _pickRange,
                  ),
                ),
                if (_range != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _range = null),
                      child: Text(context.tTone('clearRange')),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: PLDesign.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _generating ? 'Generating…' : 'Generate & save summary',
                  ),
                ),
              ],
            ),
    );
  }
}
