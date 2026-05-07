import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';

import '../design/design.dart';
import '../services/ai_service.dart';
import '../services/case_messaging_service.dart';
import '../services/message_service.dart';
import 'widgets/ai_loading_skeleton.dart';

/// AI-driven insights: summaries, compliance risk, messaging analysis.
/// Accent: purple — distinct from [TimelineViolationsScreen] (blue).
class CaseInsightsScreen extends StatefulWidget {
  const CaseInsightsScreen({
    super.key,
    required this.caseId,
    this.embedInParent = false,
  });

  final String caseId;
  final bool embedInParent;

  static const Color accent = Color(0xFF8B5CF6);

  @override
  State<CaseInsightsScreen> createState() => _CaseInsightsScreenState();
}

class _CaseInsightsScreenState extends State<CaseInsightsScreen> {
  bool _loading = true;
  String? _error;
  List<String> _lines = const [];
  String _summary = '';
  String _riskLevel = 'low';
  List<String> _issues = const [];
  Map<String, dynamic>? _fairness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      AiService.clearCache();
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final transcript = await MessageService.buildThreadTranscript(
        widget.caseId,
        CaseMessagingService.defaultConversationId,
        limit: 150,
      );
      var lines = transcript
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (lines.isEmpty && transcript.trim().length >= 12) {
        lines = [transcript.trim()];
      }

      Map<String, dynamic>? fair;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final props = await FirebaseFirestore.instance
              .collection('proposals')
              .where('caseId', isEqualTo: widget.caseId)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();
          if (props.docs.isNotEmpty) {
            final d = props.docs.first.data();
            final parts = <String>[];
            for (final k in ['title', 'summary', 'body', 'description', 'text', 'notes']) {
              final v = d[k];
              if (v != null && v.toString().trim().isNotEmpty) {
                parts.add(v.toString());
              }
            }
            final proposalText = parts.join('\n');
            if (proposalText.length > 12) {
              fair = await AiService.analyzeFairness(proposalText, forceRefresh: refresh);
            }
          }
        } catch (_) {}
      }

      String summary = '';
      if (lines.isNotEmpty) {
        try {
          summary = await AiService.generateCourtSummary(lines, forceRefresh: refresh);
        } catch (_) {
          summary = '';
        }
      }

      final compliance = lines.isEmpty
          ? <String, dynamic>{'riskLevel': 'low', 'issues': <String>[]}
          : await AiService.detectComplianceIssues(lines, forceRefresh: refresh);

      final risk = (compliance['riskLevel'] ?? 'low').toString();
      final raw = compliance['issues'];
      final issueList = <String>[];
      if (raw is List) {
        for (final e in raw) {
          final s = e.toString().trim();
          if (s.isNotEmpty) issueList.add(s);
        }
      }

      if (!mounted) return;
      setState(() {
        _lines = lines;
        _summary = summary.trim();
        _riskLevel = risk;
        _issues = issueList;
        _fairness = fair;
        _loading = false;
      });
      if (compliance['_insightsUnavailable'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AiService.insightsUnavailableMessage)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AiService.userFacingMessage(e);
      });
    }
  }

  bool get _noTranscript => _lines.isEmpty;

  Color _riskColor(String r) {
    switch (r) {
      case 'high':
        return PLDesign.danger;
      case 'medium':
        return PLDesign.warning;
      default:
        return PLDesign.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBar = widget.embedInParent
        ? null
        : AppBar(
            elevation: 0,
            backgroundColor: PLDesign.surface,
            foregroundColor: PLDesign.textPrimary,
            iconTheme: const IconThemeData(color: CaseInsightsScreen.accent),
            title: Text(
              context.tTone('insightsTitle'),
              style: PLDesign.sectionTitle.copyWith(
                color: PLDesign.textPrimary,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : () => _load(refresh: true),
                icon: Icon(Icons.refresh_rounded,
                    color: CaseInsightsScreen.accent.withValues(alpha: 0.9)),
              ),
            ],
          );

    final bodyContent = _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: AiInsightCardSkeleton(),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: PLDesign.danger),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: PLDesign.body),
                        const SizedBox(height: 20),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: CaseInsightsScreen.accent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _load(refresh: true),
                          child: Text(context.tTone('tryAgain')),
                        ),
                      ],
                    ),
                  ),
                )
              : _noTranscript && _fairness == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome_outlined,
                              size: 56,
                              color: CaseInsightsScreen.accent.withValues(alpha: 0.55),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No insights yet',
                              style: PLDesign.sectionTitle.copyWith(fontSize: 20),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Add a few messages in your co-parent thread or save a proposal '
                              'to generate summaries, tone analysis, and compliance signals.',
                              style: PLDesign.caption.copyWith(
                                color: PLDesign.textMuted,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      children: [
                        _sectionCard(
                          icon: Icons.summarize_outlined,
                          title: 'AI case summary',
                          child: _summary.isEmpty
                              ? Text(
                                  'Not enough recorded messages yet for a court-style summary.',
                                  style: PLDesign.caption.copyWith(height: 1.35),
                                )
                              : Text(
                                  _summary,
                                  style: PLDesign.body.copyWith(height: 1.4, fontSize: 14),
                                ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          icon: Icons.shield_outlined,
                          title: 'Case activity overview',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: _riskColor(_riskLevel), size: 26),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Risk level',
                                          style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                                        ),
                                        Text(
                                          _riskLevel.toUpperCase(),
                                          style: PLDesign.sectionTitle.copyWith(
                                            color: _riskColor(_riskLevel),
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_issues.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'Items to review (${_issues.length})',
                                  style: PLDesign.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: PLDesign.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._issues.map(
                                  (issue) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      '· $issue',
                                      style: PLDesign.caption.copyWith(height: 1.35),
                                    ),
                                  ),
                                ),
                              ] else
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    'No elevated issues detected in the latest scan.',
                                    style: PLDesign.caption.copyWith(height: 1.35),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          icon: Icons.forum_outlined,
                          title: 'Messaging & proposals',
                          child: _fairness == null
                              ? Text(
                                  'No saved proposal found for fairness scoring. '
                                  'Create a proposal to see how balanced the language reads.',
                                  style: PLDesign.caption.copyWith(height: 1.35),
                                )
                              : Builder(
                                  builder: (_) {
                                    final f = _fairness!;
                                    final rawScore = f['score'];
                                    final scoreStr = rawScore is num
                                        ? rawScore.toStringAsFixed(0)
                                        : '—';
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Latest proposal: ${f['result'] ?? '—'} · score $scoreStr',
                                          style: PLDesign.body.copyWith(
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          (f['reasoning'] ?? '').toString(),
                                          style: PLDesign.caption.copyWith(height: 1.4),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: PLDesign.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: CaseInsightsScreen.accent.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: CaseInsightsScreen.accent, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Informational only — not legal advice. Discuss findings with counsel before relying on them.',
                                  style: PLDesign.caption.copyWith(height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

    final body = widget.embedInParent
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: PLDesign.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tTone('insightsTitle'),
                          style: PLDesign.sectionTitle.copyWith(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _loading ? null : () => _load(refresh: true),
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: CaseInsightsScreen.accent.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: bodyContent),
            ],
          )
        : bodyContent;

    return Scaffold(
      primary: !widget.embedInParent,
      backgroundColor: PLDesign.background,
      appBar: appBar,
      body: body,
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CaseInsightsScreen.accent.withValues(alpha: 0.35)),
        boxShadow: PLDesign.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CaseInsightsScreen.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: PLDesign.sectionTitle.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
