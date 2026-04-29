import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/design.dart';
import '../util/exchange_maps_uri.dart';
import 'case_unified_timeline_screen.dart';

/// Shown after a successful schedule; summarizes the legally recorded exchange.
class ExchangeScheduledConfirmationScreen extends StatelessWidget {
  const ExchangeScheduledConfirmationScreen({
    super.key,
    required this.caseId,
    required this.exchangeId,
    required this.scheduledTime,
    required this.locationLabel,
    required this.lat,
    required this.lng,
  });

  final String caseId;
  final String exchangeId;
  final DateTime scheduledTime;
  final String locationLabel;
  final double lat;
  final double lng;

  Future<void> _openMaps(BuildContext context) async {
    final uri = exchangeMapsUri(lat, lng);
    try {
      final ok = await canLaunchUrl(uri);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tTone('couldNotOpenMapsOn'))),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('couldNotOpenMaps'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayFmt = DateFormat.yMMMd();
    final timeFmt = DateFormat.jm();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('exchangeScheduled')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: PLDesign.gradientCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: PLDesign.success, size: 44),
                const SizedBox(height: 16),
                Text(
                  'Exchange Scheduled',
                  style: PLDesign.heroTitle.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  'This exchange is on your case file with a server time stamp.',
                  style: PLDesign.caption.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Summary', style: PLDesign.sectionTitle),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PLDesign.card,
              borderRadius: PLDesign.r16,
              border: Border.all(color: PLDesign.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date', style: PLDesign.caption),
                Text(dayFmt.format(scheduledTime),
                    style: PLDesign.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Text('Time', style: PLDesign.caption),
                Text(timeFmt.format(scheduledTime),
                    style: PLDesign.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Text('Location', style: PLDesign.caption),
                Text(
                  locationLabel,
                  style: PLDesign.body.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                  style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                ),
                const SizedBox(height: 12),
                Text(
                  'Exchange record: $exchangeId',
                  style: PLDesign.caption.copyWith(
                    color: PLDesign.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
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
            onPressed: () => _openMaps(context),
            icon: const Icon(Icons.navigation_rounded),
            label: Text(context.tTone('navigateToLocation')),
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
