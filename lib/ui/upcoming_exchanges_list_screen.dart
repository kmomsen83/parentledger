import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../design/design.dart';
import '../../models/exchange_model.dart';
import '../../services/exchange_service.dart';
import '../../providers/case_context.dart';

import 'upcoming_exchange_detail_screen.dart';
import 'exchange_checkin_screen.dart';
import 'create_exchange_screen.dart';

class UpcomingExchangesListScreen extends StatefulWidget {
  const UpcomingExchangesListScreen({super.key});

  @override
  State<UpcomingExchangesListScreen> createState() =>
      _UpcomingExchangesListScreenState();
}

class _UpcomingExchangesListScreenState
    extends State<UpcomingExchangesListScreen> {
  bool navigating = false;

  void openExchange(ExchangeModel e) {
    if (navigating) return;
    navigating = true;

    final diff = e.scheduledTime.difference(DateTime.now());
    final isActive = diff.inMinutes <= 15;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isActive
            ? ExchangeCheckinScreen(
                caseId: e.caseId,
                scheduledExchange: e,
              )
            : UpcomingExchangeDetailScreen(exchange: e),
      ),
    ).then((_) {
      navigating = false;
    });
  }

  String countdown(ExchangeModel e) {
    final diff = e.scheduledTime.difference(DateTime.now());

    if (diff.isNegative) return 'In progress';
    if (diff.inMinutes <= 60) return '${diff.inMinutes}m';

    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  Color statusColor(ExchangeModel e) {
    final diff = e.scheduledTime.difference(DateTime.now());

    if (diff.inMinutes <= 15) return PLDesign.success;
    if (diff.inHours < 24) return Colors.orange;

    return Colors.blueAccent;
  }

  Future<void> refresh() async {
    setState(() {});
  }

  void scheduleNewExchange() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateExchangeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caseId = Provider.of<CaseContext>(context).caseId;

    if (caseId == null) {
      return Scaffold(
        body: Center(child: Text(context.tTone('noCaseSelected'))),
      );
    }

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('upcomingExchanges')),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: StreamBuilder<List<ExchangeModel>>(
          stream: ExchangeService.watchUpcoming(caseId),
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Something went wrong',
                      style: PLDesign.sectionTitle,
                    ),
                  ),
                ],
              );
            }

            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final exchanges = snap.data ?? [];

            if (exchanges.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PLDesign.primary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: PLDesign.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        Icons.event_note_rounded,
                        size: 48,
                        color: PLDesign.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'No upcoming exchanges',
                    textAlign: TextAlign.center,
                    style: PLDesign.heroTitle.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Stay organized by scheduling your next exchange',
                    textAlign: TextAlign.center,
                    style: PLDesign.body.copyWith(
                      color: PLDesign.textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'All exchanges are time-stamped and recorded for your case file',
                    textAlign: TextAlign.center,
                    style: PLDesign.caption.copyWith(
                      color: PLDesign.textMuted,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 36),
                  FilledButton.icon(
                    onPressed: scheduleNewExchange,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.tTone('scheduleNewExchange')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                ],
              );
            }

            final next = exchanges.first;

            return Stack(
              children: [
                ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (!next.scheduledTime.isBefore(DateTime.now()))
                      _nextExchangeCard(next),
                    const SizedBox(height: 26),
                    const Text(
                      'All upcoming',
                      style: PLDesign.sectionTitle,
                    ),
                    const SizedBox(height: 14),
                    ...exchanges.map(_exchangeTile),
                    const SizedBox(height: 88),
                  ],
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton.extended(
                    onPressed: scheduleNewExchange,
                    icon: const Icon(Icons.add),
                    label: Text(context.tTone('schedule')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _nextExchangeCard(ExchangeModel e) {
    return GestureDetector(
      onTap: () => openExchange(e),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              PLDesign.primary.withValues(alpha: 0.22),
              PLDesign.card,
            ],
          ),
          borderRadius: PLDesign.r20,
          border: Border.all(color: PLDesign.primary.withValues(alpha: 0.65)),
          boxShadow: PLDesign.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next exchange',
              style: PLDesign.caption.copyWith(
                color: PLDesign.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(e.locationName, style: PLDesign.pageTitle),
            const SizedBox(height: 6),
            Text(
              DateFormat.yMMMd().add_jm().format(e.scheduledTime),
              style: PLDesign.caption,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _pill(countdown(e), statusColor(e)),
                const SizedBox(width: 10),
                _pill(e.type, Colors.blueAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _exchangeTile(ExchangeModel e) {
    return GestureDetector(
      onTap: () => openExchange(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PLDesign.card,
          borderRadius: PLDesign.r20,
          border: Border.all(color: PLDesign.border),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 50,
              decoration: BoxDecoration(
                color: statusColor(e),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.locationName,
                    style: PLDesign.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.yMMMd().add_jm().format(e.scheduledTime),
                    style: PLDesign.caption,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  countdown(e),
                  style: TextStyle(
                    color: statusColor(e),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
