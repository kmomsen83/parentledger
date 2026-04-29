import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';

import '../design/design.dart';

class AiFairnessSuggestionScreen extends StatelessWidget {
  const AiFairnessSuggestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('aiFairnessAnalysis')),
        backgroundColor: PLDesign.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xff4f46e5), Color(0xff1d4ed8)],
                ),
                boxShadow: PLDesign.softShadow,
              ),
              child: const Row(
                children: [
                  Icon(Icons.balance_rounded, color: Colors.white, size: 34),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Fairness Score',
                          style: TextStyle(color: Colors.white70),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '82%',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Based on recorded proposals and schedule events. Informational only, not legal advice.',
              style: PLDesign.caption.copyWith(height: 1.35),
            ),
            const SizedBox(height: 20),
            const Text('Parenting Time Distribution', style: PLDesign.sectionTitle),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: PLDesign.elevatedCard,
              child: Column(
                children: [
                  _distRow('You', .54, PLDesign.info),
                  const SizedBox(height: 16),
                  _distRow('Other Parent', .46, PLDesign.ai),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('AI Reasoning', style: PLDesign.sectionTitle),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: PLDesign.elevatedCard,
              child: Text(
                'Recent schedule proposals increased imbalance slightly. AI recommends redistributing one weekday overnight to maintain long-term fairness and reduce dispute risk.',
                style: PLDesign.caption.copyWith(height: 1.4, color: PLDesign.textMuted),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Suggested Compromise', style: PLDesign.sectionTitle),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xff22c55e), Color(0xff15803d)],
                ),
              ),
              child: const Text(
                'Transfer Wednesday overnight exchange to other parent starting next week.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tTone('counterSuggestionFlowOpensFrom')),
                        ),
                      );
                    },
                    child: Text(context.tTone('counterSuggestion')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tTone('aiCompromiseSavedToReview')),
                        ),
                      );
                    },
                    child: Text(context.tTone('acceptAiProposal')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _distRow(String label, double value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: PLDesign.body.copyWith(color: Colors.white)),
            Text(
              '${(value * 100).toInt()}%',
              style: PLDesign.body.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            backgroundColor: PLDesign.border,
            color: color,
          ),
        ),
      ],
    );
  }
}
