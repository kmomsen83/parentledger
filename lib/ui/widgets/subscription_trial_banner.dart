import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../providers/case_context.dart';
import '../../services/revenuecat_service.dart';

/// Trial countdown — documentation/clarity framing (not payments).
class SubscriptionTrialBanner extends StatefulWidget {
  const SubscriptionTrialBanner({super.key});

  @override
  State<SubscriptionTrialBanner> createState() =>
      _SubscriptionTrialBannerState();
}

class _SubscriptionTrialBannerState extends State<SubscriptionTrialBanner> {
  int? _trialDays;
  CaseContext? _session;

  Future<void> _refresh() async {
    final session = _session;
    if (session == null ||
        session.isAttorney ||
        !session.hasRevenueCatPremium) {
      if (_trialDays != null && mounted) setState(() => _trialDays = null);
      return;
    }
    final days = await RevenueCatService.trialDaysRemaining();
    if (!mounted) return;
    setState(() => _trialDays = days);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _session = context.read<CaseContext>();
      _session!.addListener(_onSessionChanged);
      _refresh();
    });
  }

  void _onSessionChanged() => _refresh();

  @override
  void dispose() {
    _session?.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    if (session.isAttorney ||
        !session.hasRevenueCatPremium ||
        _trialDays == null) {
      return const SizedBox.shrink();
    }

    final days = _trialDays!;
    final urgent = days <= 3;

    final line1 = days <= 0
        ? 'Your free trial ends today.'
        : 'Your free trial ends in $days ${days == 1 ? 'day' : 'days'}.';

    final line2 = urgent
        ? 'Trial ending soon — don\'t lose your records.'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: urgent
            ? PLDesign.warning.withValues(alpha: 0.14)
            : PLDesign.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: urgent
                ? PLDesign.warning.withValues(alpha: 0.55)
                : PLDesign.border.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.schedule_rounded,
                color: urgent ? PLDesign.warning : PLDesign.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line1,
                      style: PLDesign.body.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (line2 != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        line2,
                        style: PLDesign.body.copyWith(
                          color: PLDesign.textMuted,
                          height: 1.35,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
