import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';
import '../models/exchange_model.dart';
import '../services/exchange_service.dart';

/// Exchanges that are missed or overdue (scheduled in the past, not completed).
class AttorneyMissedExchangesScreen extends StatelessWidget {
  const AttorneyMissedExchangesScreen({
    super.key,
    required this.caseId,
  });

  final String caseId;

  bool _isMissed(ExchangeModel e) {
    if (e.status == 'missed') return true;
    if (e.status != 'scheduled') return false;
    return e.scheduledTime.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('missedOverdueExchanges')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ExchangeService.watchAllExchanges(caseId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                '${snap.error}',
                style: PLDesign.body.copyWith(color: PLDesign.danger),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!.docs
              .map((d) => ExchangeModel.fromDoc(d, caseId: caseId))
              .where(_isMissed)
              .toList();

          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No missed or overdue exchanges detected in this case record.',
                  style: PLDesign.body.copyWith(height: 1.35),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final e = list[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PLDesign.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PLDesign.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.type.toUpperCase(),
                      style: PLDesign.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: PLDesign.warning,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      e.locationName,
                      style: PLDesign.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scheduled ${df.format(e.scheduledTime)}',
                      style: PLDesign.caption,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${e.status}',
                      style: PLDesign.caption,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
