import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:parentledger/design/design.dart';

import '../services/ai_service.dart';
import 'widgets/ai_loading_skeleton.dart';
import '../services/case_messaging_service.dart';
import '../services/message_service.dart';

/// Full compliance scan using [AiService.detectComplianceIssues].
class AiViolationsScreen extends StatefulWidget {
  const AiViolationsScreen({super.key, required this.caseId});

  final String caseId;

  @override
  State<AiViolationsScreen> createState() => _AiViolationsScreenState();
}

class _AiViolationsScreenState extends State<AiViolationsScreen> {
  bool _loading = true;
  bool _scanInFlight = false;
  String? _error;
  String _riskLevel = 'low';
  List<String> _issues = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runScan());
  }

  Future<void> _runScan({bool bypassCache = false}) async {
    if (_scanInFlight) return;
    _scanInFlight = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (bypassCache) {
      AiService.clearCache();
    }
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
      if (lines.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _riskLevel = 'low';
          _issues = const [];
        });
        return;
      }
      if (!bypassCache) {
        final peek = await AiService.peekComplianceCache(lines);
        if (!mounted) return;
        if (peek != null) {
          final riskP = (peek['riskLevel'] ?? 'low').toString();
          final rawP = peek['issues'];
          final outP = <String>[];
          if (rawP is List) {
            for (final e in rawP) {
              final s = e.toString().trim();
              if (s.isNotEmpty) outP.add(s);
            }
          }
          setState(() {
            _riskLevel = riskP;
            _issues = outP;
          });
        }
      }
      final res = await AiService.detectComplianceIssues(
        lines,
        forceRefresh: bypassCache,
      );
      if (!mounted) return;
      final risk = (res['riskLevel'] ?? 'low').toString();
      final raw = res['issues'];
      final out = <String>[];
      if (raw is List) {
        for (final e in raw) {
          final s = e.toString().trim();
          if (s.isNotEmpty) out.add(s);
        }
      }
      setState(() {
        _loading = false;
        _riskLevel = risk;
        _issues = out;
        _error = null;
      });
      if (res['_insightsUnavailable'] == true && mounted) {
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
    } finally {
      _scanInFlight = false;
    }
  }

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
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: PLDesign.surface,
        title: Text(context.tTone('aiComplianceScan')),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _runScan(bypassCache: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
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
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: PLDesign.body,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => _runScan(bypassCache: true),
                          child: Text(context.tTone('tryAgain')),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PLDesign.card,
                        borderRadius: PLDesign.r16,
                        border: Border.all(color: PLDesign.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, color: _riskColor(_riskLevel), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Risk level',
                                  style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _riskLevel.toUpperCase(),
                                  style: PLDesign.sectionTitle.copyWith(
                                    color: _riskColor(_riskLevel),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PLDesign.card,
                        borderRadius: PLDesign.r16,
                        border: Border.all(color: PLDesign.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: PLDesign.ai, size: 22),
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
                    const SizedBox(height: 16),
                    if (_issues.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 56,
                                color: PLDesign.success.withValues(alpha: 0.85),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No compliance issues reported',
                                style: PLDesign.sectionTitle,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Text(
                        'Flagged issues (${_issues.length})',
                        style: PLDesign.sectionTitle.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      ..._issues.map(
                        (issue) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: PLDesign.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: PLDesign.danger.withValues(alpha: 0.35),
                              ),
                              boxShadow: PLDesign.softShadow,
                            ),
                            child: Text(
                              issue,
                              style: PLDesign.body.copyWith(fontSize: 14, height: 1.35),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}
