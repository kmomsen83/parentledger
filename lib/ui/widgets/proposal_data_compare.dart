import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/design.dart';

/// Side-by-side labels for [before] vs [after] schedule-style maps (ISO times, etc.).
class ProposalDataCompare extends StatelessWidget {
  const ProposalDataCompare({
    super.key,
    required this.before,
    required this.after,
  });

  final Map<String, dynamic> before;
  final Map<String, dynamic> after;

  static String _labelForKey(String k) {
    switch (k) {
      case 'scheduledTime':
        return 'Date & time';
      case 'locationName':
        return 'Location';
      case 'address':
        return 'Address';
      case 'amount':
        return 'Amount';
      case 'requestedDate':
        return 'Date';
      case 'notes':
        return 'Notes';
      case 'detail':
        return 'Details';
      case 'exchangeType':
        return 'Type';
      default:
        return k.replaceAll('_', ' ');
    }
  }

  static String _formatValue(String key, dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    if (s.isEmpty) return '—';
    if (key == 'scheduledTime' || key == 'requestedDate') {
      final parsed = DateTime.tryParse(s);
      if (parsed != null) {
        return DateFormat.yMMMd().add_jm().format(parsed.toLocal());
      }
    }
    if (key == 'amount' && v is num) {
      return v.toStringAsFixed(2);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final keys = <String>{...before.keys, ...after.keys};

    if (keys.isEmpty) {
      return Text(
        'No structured fields to compare.',
        style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
      );
    }

    return Column(
      children: [
        for (final k in keys)
          _row(
            _labelForKey(k),
            _formatValue(k, before[k]),
            _formatValue(k, after[k]),
            _formatValue(k, before[k]) != _formatValue(k, after[k]),
          ),
      ],
    );
  }

  Widget _row(String label, String was, String now, bool changed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: changed
            ? PLDesign.warning.withValues(alpha: 0.06)
            : PLDesign.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: changed
              ? PLDesign.warning.withValues(alpha: 0.35)
              : PLDesign.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: PLDesign.caption.copyWith(
              color: PLDesign.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recorded',
                      style: PLDesign.caption.copyWith(
                        fontSize: 10,
                        color: PLDesign.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      was,
                      style: PLDesign.body.copyWith(
                        color: PLDesign.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: changed ? PLDesign.warning : PLDesign.textMuted,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proposed',
                      style: PLDesign.caption.copyWith(
                        fontSize: 10,
                        color: PLDesign.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      now,
                      style: PLDesign.body.copyWith(
                        color: changed ? PLDesign.warning : PLDesign.textPrimary,
                        fontWeight: changed ? FontWeight.w700 : FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
