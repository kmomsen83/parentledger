import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';
import '../models/exchange_checkin_submit_result.dart';
import 'case_unified_timeline_screen.dart';

/// Post-submit confirmation: immutable record summary and export affordances.
class ExchangeCheckinConfirmationScreen extends StatelessWidget {
  const ExchangeCheckinConfirmationScreen({
    super.key,
    required this.caseId,
    required this.exchangeId,
    required this.result,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
  });

  final String caseId;
  final String? exchangeId;
  final ExchangeCheckinSubmitResult result;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;

  String _exportBody() {
    final buf = StringBuffer()
      ..writeln('PARENTLEDGER — EXCHANGE CHECK-IN RECORD (COPY)')
      ..writeln('This is a user copy. The authoritative record is stored securely and cannot be edited.')
      ..writeln()
      ..writeln('Check-in ID: ${result.checkInId}');
    if (exchangeId != null && exchangeId!.isNotEmpty) {
      buf.writeln('Exchange ID: $exchangeId');
    }
    buf
      ..writeln('Case ID: $caseId')
      ..writeln('Content hash: ${result.contentHash}')
      ..writeln()
      ..writeln(
        'Device timestamp: ${DateFormat.yMMMd().add_jm().format(result.deviceTimestamp)}',
      );
    if (result.arrivalTiming != null) {
      buf.writeln('Arrival timing: ${result.arrivalTiming}');
    }
    if (result.minutesFromScheduled != null) {
      buf.writeln('Minutes from scheduled: ${result.minutesFromScheduled}');
    }
    buf
      ..writeln()
      ..writeln('Address on record: ${result.recordedAddress}');
    if (latitude != null && longitude != null) {
      buf.writeln(
        'GPS: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
      );
    }
    if (accuracyMeters != null) {
      buf.writeln('Location accuracy (m): ${accuracyMeters!.toStringAsFixed(1)}');
    }
    return buf.toString();
  }

  Future<void> _copyExport(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _exportBody()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Record copied — paste into email, cloud storage, or counsel.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_jm();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('checkinRecorded')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: PLDesign.gradientCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_rounded, color: PLDesign.success, size: 40),
                const SizedBox(height: 14),
                Text(
                  'Check-In Recorded',
                  style: PLDesign.heroTitle.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  'This record is securely stored and cannot be edited.',
                  style: PLDesign.body.copyWith(
                    color: PLDesign.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Summary', style: PLDesign.sectionTitle),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: PLDesign.card,
              borderRadius: PLDesign.r16,
              border: Border.all(color: PLDesign.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Timestamp', style: PLDesign.caption),
                Text(
                  fmt.format(result.deviceTimestamp),
                  style: PLDesign.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text('Address', style: PLDesign.caption),
                Text(
                  result.recordedAddress,
                  style: PLDesign.body.copyWith(height: 1.35),
                ),
                if (latitude != null && longitude != null) ...[
                  const SizedBox(height: 16),
                  Text('GPS coordinates', style: PLDesign.caption),
                  Text(
                    '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                    style: PLDesign.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                if (accuracyMeters != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Accuracy ±${accuracyMeters!.toStringAsFixed(0)} m',
                    style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PLDesign.primary.withValues(alpha: 0.08),
              borderRadius: PLDesign.r16,
              border: Border.all(
                color: PLDesign.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Each parent may complete their own check-in for the same exchange. '
              'Late arrivals are flagged for compliance review when applicable.',
              style: PLDesign.caption.copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CaseUnifiedTimelineScreen(caseId: caseId),
                ),
              );
            },
            icon: const Icon(Icons.timeline_rounded),
            label: Text(context.tTone('viewTimeline')),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _copyExport(context),
            icon: const Icon(Icons.copy_rounded),
            label: Text(context.tTone('exportRecord')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: PLDesign.textPrimary,
              side: BorderSide(color: PLDesign.border),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tTone('done')),
            ),
          ),
        ],
      ),
    );
  }
}
