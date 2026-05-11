import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../util/subscription_gate.dart';
import '../services/case_messaging_service.dart';
import '../services/counsel_access_policy.dart';
import '../services/message_service.dart';
import '../services/ai_service.dart';
import 'widgets/ai_loading_skeleton.dart';
import '../services/court_pdf_service.dart';
import '../services/legal_summary_service.dart';
import 'legal_summary_detail_screen.dart';
import 'legal_transcription_screen.dart';
import 'widgets/empty_state_panel.dart';
import 'widgets/trust_elements.dart';

bool hasCoParent(List<String>? participants, String currentUserId) {
  if (participants == null || participants.isEmpty) return false;
  return participants.where((id) => id != currentUserId).isNotEmpty;
}

/// Legally defensible case messaging — NOT a casual chat.
class ConversationThreadScreen extends StatefulWidget {
  const ConversationThreadScreen({
    super.key,
    required this.title,
    required this.caseId,
    String? conversationId,
    this.flaggedOnly = false,
    this.initialComposerText,
    this.embedInParent = false,
  }) : conversationId =
            conversationId ?? CaseMessagingService.defaultConversationId;

  final String title;
  final String caseId;
  final String conversationId;

  /// Nested under counsel [ClientCaseScreen] tabs (no app bar).
  final bool embedInParent;

  /// When true, only messages with a [legalFlag] are listed (attorney filter).
  final bool flaggedOnly;

  /// Optional draft placed in the composer (e.g. day context from calendar).
  final String? initialComposerText;

  @override
  State<ConversationThreadScreen> createState() =>
      _ConversationThreadScreenState();
}

class _ConversationThreadScreenState extends State<ConversationThreadScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Stable streams — do not call [watchMessages]/snapshots in [build] or scroll rebuilds
  /// race single-subscription listeners.
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _conversationDocStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  bool showWarning = false;
  bool sending = false;
  bool _toneClassifying = false;
  Map<String, dynamic>? _pendingTone;
  bool _courtSummaryBusy = false;
  bool _markedReadOnce = false;
  bool _trustBannerMinimized = false;

  /// Updated each [build] for [controller] listener (no async role lookup).
  bool _composerIsAttorney = false;

  Timer? _typingClearTimer;

  final DateFormat timeFormat = DateFormat('MMM d, yyyy • HH:mm');

  static const List<String> _tagOptions = [
    'Agreement',
    'Violation',
    'Schedule',
    'Expense',
  ];

  @override
  void initState() {
    super.initState();
    _conversationDocStream = CaseMessagingService.conversationRef(
      widget.caseId,
      widget.conversationId,
    ).snapshots();
    _messagesStream = CaseMessagingService.watchMessages(
      widget.caseId,
      widget.conversationId,
    );
    final draft = widget.initialComposerText;
    if (draft != null && draft.isNotEmpty) {
      controller.text = draft;
    }
    controller.addListener(_onComposerTextChanged);
  }

  @override
  void dispose() {
    _typingClearTimer?.cancel();
    controller.removeListener(_onComposerTextChanged);
    if (!_composerIsAttorney && widget.caseId.isNotEmpty) {
      unawaited(
        CaseMessagingService.updateTypingState(
          caseId: widget.caseId,
          conversationId: widget.conversationId,
          isTyping: false,
        ),
      );
    }
    _scrollController.dispose();
    controller.dispose();
    super.dispose();
  }

  void _onComposerTextChanged() {
    if (_composerIsAttorney || widget.caseId.isEmpty) return;
    final t = controller.text.trim();
    _typingClearTimer?.cancel();
    if (t.isEmpty) {
      unawaited(
        CaseMessagingService.updateTypingState(
          caseId: widget.caseId,
          conversationId: widget.conversationId,
          isTyping: false,
        ),
      );
      return;
    }
    unawaited(
      CaseMessagingService.updateTypingState(
        caseId: widget.caseId,
        conversationId: widget.conversationId,
        isTyping: true,
      ),
    );
    _typingClearTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (controller.text.trim().isEmpty) return;
      unawaited(
        CaseMessagingService.updateTypingState(
          caseId: widget.caseId,
          conversationId: widget.conversationId,
          isTyping: false,
        ),
      );
    });
  }

  bool _peerTypingFresh(Map<String, dynamic>? d) {
    final tu = d?['typingUserId']?.toString() ?? '';
    if (tu.isEmpty || tu == uid) return false;
    final raw = d?['typingUpdatedAt'];
    if (raw is! Timestamp) return false;
    return DateTime.now().difference(raw.toDate()) < const Duration(seconds: 8);
  }

  String _body(Map<String, dynamic> m) => (m['text'] ?? '').toString();

  bool _hasRisk(Map<String, dynamic> m) {
    return m['legalFlag'] != null;
  }

  Timestamp? _createdAt(Map<String, dynamic> m) {
    final t = m['createdAt'];
    return t is Timestamp ? t : null;
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending || _toneClassifying) return;

    if (_pendingTone == null) {
      setState(() => _toneClassifying = true);
      try {
        final tone = await AiService.classifyCoParentMessage(text);
        if (!mounted) return;
        if (tone['warnBeforeSend'] == true) {
          setState(() {
            _toneClassifying = false;
            showWarning = true;
            _pendingTone = tone;
          });
          return;
        }
        _pendingTone = tone;
      } catch (e) {
        if (!mounted) return;
        setState(() => _toneClassifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AiService.userFacingMessage(e))),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _toneClassifying = false);
    }

    setState(() => sending = true);
    try {
      await CaseMessagingService.updateTypingState(
        caseId: widget.caseId,
        conversationId: widget.conversationId,
        isTyping: false,
      );
      await CaseMessagingService.sendTextMessage(
        caseId: widget.caseId,
        conversationId: widget.conversationId,
        text: text,
        toneClassification: _pendingTone,
      );
      controller.clear();
      _pendingTone = null;
      showWarning = false;
      _scrollToLatest();
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Send message failed');
      }
      if (!mounted) return;
      _pendingTone = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('couldNotSendMessageTry'))),
      );
    }
    if (!mounted) return;
    setState(() => sending = false);
  }

  Future<void> _sendDespiteWarning() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending || _pendingTone == null) return;
    setState(() {
      showWarning = false;
      sending = true;
    });
    try {
      await CaseMessagingService.updateTypingState(
        caseId: widget.caseId,
        conversationId: widget.conversationId,
        isTyping: false,
      );
      await CaseMessagingService.sendTextMessage(
        caseId: widget.caseId,
        conversationId: widget.conversationId,
        text: text,
        toneClassification: _pendingTone,
      );
      controller.clear();
      _pendingTone = null;
      _scrollToLatest();
    } catch (_) {
      if (!mounted) return;
      _pendingTone = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('couldNotSendMessageTry'))),
      );
    }
    if (!mounted) return;
    setState(() => sending = false);
  }

  void _applyToneSuggestion() {
    final suggestion = (_pendingTone?['neutralRewrite'] as String?)?.trim();
    if (suggestion == null || suggestion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('noAiSuggestionAvailableFor'))),
      );
      return;
    }
    setState(() {
      controller.text = suggestion;
      showWarning = false;
      _pendingTone = null;
    });
  }

  Future<void> _exportPdf({
    DateTime? since,
    bool flaggedOnly = false,
  }) async {
    final session = context.read<CaseContext>();
    final allowExport = session.isPremium || session.isAttorney;
    if (!await requirePremiumOrPrompt(context, guard: allowExport)) return;
    if (!mounted) return;

    if (session.isAttorney) {
      final wait = await CounselAccessPolicy.exportCooldownRemaining();
      if (wait != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait a moment before exporting again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    try {
      final docs = await MessageService.getMessagesForExport(
        widget.caseId,
        since: since,
        flaggedOnly: flaggedOnly,
      );
      final entries = _pdfEntries(docs);
      final label = DateFormat('MM/dd/yyyy HH:mm').format(DateTime.now());
      await CourtPdfService.generateCommunicationLog(
        conversationTitle: widget.title,
        generatedAtLabel: label,
        entries: entries,
        caseId: widget.caseId,
      );
      if (session.isAttorney) {
        await CounselAccessPolicy.recordExportCompleted();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _generateAttorneyBrief() async {
    final session = context.read<CaseContext>();
    final allow = session.isAttorney || session.unlockedParentPremiumFeatures;
    if (!await requirePremiumOrPrompt(context, guard: allow)) return;
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(context.tTone('generatingAttorneyBrief')),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final summaryId = await LegalSummaryService.generateAttorneyCourtSummaryAndStore(
        caseId: widget.caseId,
        messageLimit: 100,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LegalSummaryDetailScreen(
            caseId: widget.caseId,
            summaryId: summaryId,
          ),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tTone('attorneyBriefSavedToLegal')),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not build brief: $e')),
      );
    }
  }

  Future<void> _generateAiCourtSummary() async {
    if (_courtSummaryBusy) return;
    setState(() => _courtSummaryBusy = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          color: PLDesign.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 260,
                  child: AiInsightCardSkeleton(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Generating court summary…',
                  style: TextStyle(color: PLDesign.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final transcript = await MessageService.buildThreadTranscript(
        widget.caseId,
        widget.conversationId,
        limit: 150,
      );
      if (transcript.length < 20) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tTone('addAFewMoreMessages')),
            ),
          );
        }
        return;
      }
      final lines = transcript
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final payload = lines.isNotEmpty ? lines : <String>[transcript.trim()];
      final summary = await AiService.generateCourtSummary(payload);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: PLDesign.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (context, scroll) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PLDesign.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Court summary (AI)',
                      style: PLDesign.sectionTitle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Neutral, chronological overview for documentation. Not legal advice.',
                      style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: PLDesign.card,
                          borderRadius: PLDesign.r16,
                          border: Border.all(color: PLDesign.border),
                        ),
                        child: SingleChildScrollView(
                          controller: scroll,
                          child: SelectableText(
                            summary,
                            style: PLDesign.body.copyWith(height: 1.45, fontSize: 14),
                          )
                              .animate()
                              .fadeIn(duration: 320.ms, curve: Curves.easeOutCubic),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.tTone('close')),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      try {
        final transcript = await MessageService.buildThreadTranscript(
          widget.caseId,
          widget.conversationId,
          limit: 150,
        );
        final lines = transcript
            .split(RegExp(r'\r?\n'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final payload = lines.isNotEmpty ? lines : <String>[transcript.trim()];
        final stale = await AiService.peekCourtSummaryCache(payload);
        if (!mounted) return;
        if (stale != null &&
            stale.isNotEmpty &&
            stale != AiService.insightsUnavailableMessage) {
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: PLDesign.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) {
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.88,
                minChildSize: 0.45,
                maxChildSize: 0.95,
                builder: (context, scroll) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: PLDesign.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Court summary (cached)',
                          style: PLDesign.sectionTitle.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AiService.insightsUnavailableMessage,
                          style: PLDesign.caption.copyWith(color: PLDesign.warning),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: PLDesign.card,
                              borderRadius: PLDesign.r16,
                              border: Border.all(color: PLDesign.border),
                            ),
                            child: SingleChildScrollView(
                              controller: scroll,
                              child: SelectableText(
                                stale,
                                style: PLDesign.body.copyWith(height: 1.45, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.tTone('close')),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AiService.userFacingMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _courtSummaryBusy = false);
    }
  }

  Future<void> _saveExtendedCaseSummary() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(context.tTone('savingExtendedCaseSummary')),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final summaryId = await LegalSummaryService.generateAndStore(
        caseId: widget.caseId,
        messageLimit: 100,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LegalSummaryDetailScreen(
            caseId: widget.caseId,
            summaryId: summaryId,
          ),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tTone('summarySavedToYourCase2')),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not build summary: $e')),
      );
    }
  }

  List<Map<String, String>> _pdfEntries(List<QueryDocumentSnapshot> docs) {
    final out = <Map<String, String>>[];
    for (final d in docs) {
      final m = d.data() as Map<String, dynamic>;
      final ts = _createdAt(m);
      final time = ts != null ? DateFormat('MMMM d, yyyy').format(ts.toDate()) : '—';
      final senderId = (m['senderId'] ?? '').toString();
      final body = _body(m);
      out.add({
        'date': time,
        'senderId': senderId.isEmpty ? 'unknown' : senderId,
        'message': body,
      });
    }
    return out;
  }

  Map<String, int> _summaryFromDocs(List<QueryDocumentSnapshot> docs) {
    var hostile = 0;
    var nonCompliant = 0;
    for (final d in docs) {
      final m = d.data() as Map<String, dynamic>;
      final f = m['legalFlag']?.toString();
      if (f == 'hostile') hostile++;
      if (f == 'non-compliant') nonCompliant++;
    }
    return <String, int>{
      'hostile': hostile,
      'nonCompliant': nonCompliant,
    };
  }

  List<String> _summaryLines(Map<String, int> c) {
    final lines = <String>[];
    if ((c['hostile'] ?? 0) > 0) {
      final n = c['hostile']!;
      lines.add(
        '$n message${n == 1 ? '' : 's'} flagged hostile (stored legal metadata)',
      );
    }
    if ((c['nonCompliant'] ?? 0) > 0) {
      final n = c['nonCompliant']!;
      lines.add(
        '$n message${n == 1 ? '' : 's'} flagged non-compliant (stored legal metadata)',
      );
    }
    return lines;
  }

  String _deliveryLine({required Map<String, dynamic> m}) {
    final created = _createdAt(m) != null;
    if (!created) return 'Sending…';
    final read = m['isRead'] == true;
    return read ? 'Delivered · Read' : 'Delivered · Unread';
  }

  Future<void> _openTagSheet(
    String messageId,
    List<String> current, {
    required bool important,
    required bool markedAsEvidence,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: PLDesign.surface,
      isScrollControlled: true,
      builder: (ctx) {
        final selected = List<String>.from(current);
        var imp = important;
        var ev = markedAsEvidence;
        return StatefulBuilder(
          builder: (context, setModal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mark for court',
                      style: PLDesign.sectionTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These markers help organize records for review and export.',
                      style: PLDesign.caption,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Highlight for review'),
                      subtitle: Text(context.tTone('highlightForReviewAndExports')),
                      value: imp,
                      onChanged: (v) => setModal(() => imp = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Flag for court review'),
                      subtitle: Text(context.tTone('flagForDisclosureBundles')),
                      value: ev,
                      onChanged: (v) => setModal(() => ev = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Categories',
                      style: PLDesign.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tagOptions.map((t) {
                        final on = selected.contains(t);
                        return FilterChip(
                          label: Text(t),
                          selected: on,
                          onSelected: (v) {
                            setModal(() {
                              if (v) {
                                if (!selected.contains(t)) selected.add(t);
                              } else {
                                selected.remove(t);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          try {
                            await CaseMessagingService.updateMessageTags(
                              caseId: widget.caseId,
                              conversationId: widget.conversationId,
                              messageId: messageId,
                              tags: selected.toSet().toList(),
                            );
                            await CaseMessagingService.updateMessageLegalMarks(
                              caseId: widget.caseId,
                              conversationId: widget.conversationId,
                              messageId: messageId,
                              important: imp,
                              markedAsEvidence: ev,
                            );
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Could not save: $e')),
                              );
                            }
                          }
                        },
                        child: Text(context.tTone('save')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  Widget _bubble(QueryDocumentSnapshot doc, {required bool readOnly}) {
    final m = doc.data() as Map<String, dynamic>;
    final mine = m['senderId'] == uid;
    final risk = _hasRisk(m);
    final legalFlag = m['legalFlag']?.toString();
    final ts = _createdAt(m);
    final time = ts != null ? ts.toDate() : DateTime.now();
    final tags = (m['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final important = m['important'] == true;
    final evidence = m['markedAsEvidence'] == true;

    final maxW = MediaQuery.of(context).size.width * 0.84;

    final bubbleDecoration = mine
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xff3b82f6),
                Color(0xff2563eb),
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: const Radius.circular(18),
              bottomRight: const Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: PLDesign.primary.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: const Color(0xff1e293b),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomRight: const Radius.circular(18),
              bottomLeft: const Radius.circular(4),
            ),
            border: Border.all(color: PLDesign.border),
            boxShadow: PLDesign.softShadow,
          );

    final fg = Colors.white;
    final subFg = Colors.white.withValues(alpha: 0.82);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: readOnly
            ? null
            : () {
                _openTagSheet(
                  doc.id,
                  tags,
                  important: important,
                  markedAsEvidence: evidence,
                );
              },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: maxW),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: bubbleDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (important || evidence)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (important)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: PLDesign.warning,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Important',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: subFg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (evidence)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fact_check_rounded,
                                    size: 16,
                                    color: PLDesign.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Evidence',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: subFg,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    if (legalFlag != null && legalFlag.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.gavel,
                              size: 14,
                              color: PLDesign.warning.withValues(alpha: 0.95),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              legalFlag,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: PLDesign.warning.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (risk && legalFlag == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: subFg,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Review suggested — language may affect your record',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: subFg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      _body(m),
                      style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subFg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeFormat.format(time),
                style: PLDesign.caption.copyWith(
                  fontSize: 10,
                  color: PLDesign.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _deliveryLine(m: m),
                style: PLDesign.caption.copyWith(
                  fontSize: 10,
                  color: PLDesign.textMuted.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAttorney = context.watch<CaseContext>().isAttorney;
    _composerIsAttorney = isAttorney;

    if (widget.caseId.isEmpty) {
      return Scaffold(
        primary: !widget.embedInParent,
        backgroundColor: PLDesign.background,
        appBar: widget.embedInParent
            ? null
            : AppBar(
                backgroundColor: PLDesign.surface,
                foregroundColor: PLDesign.textPrimary,
                title: Text(context.tTone('messages')),
              ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.link_off, size: 52, color: PLDesign.danger),
                const SizedBox(height: 18),
                Text(
                  'No case linked',
                  textAlign: TextAlign.center,
                  style: PLDesign.sectionTitle,
                ),
                const SizedBox(height: 10),
                Text(
                  'Connect a custody case in your workspace before opening the legal message log.',
                  textAlign: TextAlign.center,
                  style: PLDesign.body,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final exportFullLabel = context.tTone('exportPdfFullThread');
    final export30Label = context.tTone('exportPdfLast30Days');
    final exportFlaggedLabel = context.tTone('exportPdfFlaggedRiskOnly');

    final appBar = widget.embedInParent
        ? null
        : AppBar(
            elevation: 0,
            backgroundColor: PLDesign.surface,
            foregroundColor: PLDesign.textPrimary,
            title: Text(widget.title),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.share_outlined),
                onSelected: (v) async {
                  switch (v) {
                    case 'pdf_all':
                      await _exportPdf();
                      break;
                    case 'pdf_30':
                      await _exportPdf(
                        since:
                            DateTime.now().subtract(const Duration(days: 30)),
                      );
                      break;
                    case 'pdf_flagged':
                      await _exportPdf(flaggedOnly: true);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'pdf_all',
                    child: Text(exportFullLabel),
                  ),
                  PopupMenuItem(
                    value: 'pdf_30',
                    child: Text(export30Label),
                  ),
                  PopupMenuItem(
                    value: 'pdf_flagged',
                    child: Text(exportFlaggedLabel),
                  ),
                ],
              ),
              if (!isAttorney)
                IconButton(
                  icon: const Icon(Icons.mic_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LegalTranscriptionScreen(
                          caseId: widget.caseId,
                        ),
                      ),
                    );
                  },
                ),
            ],
          );

    return Scaffold(
      primary: !widget.embedInParent,
      backgroundColor: PLDesign.background,
      appBar: appBar,
      body: Column(
        children: [
          MessageTrustBanner(
            minimized: _trustBannerMinimized,
            onToggle: () {
              setState(() => _trustBannerMinimized = !_trustBannerMinimized);
            },
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _conversationDocStream,
            builder: (context, conversationSnap) {
              final conversationData = conversationSnap.data?.data();
              final participantsRaw = conversationData?['participants'];
              final memberIdsRaw = conversationData?['memberIds'];
              final List<String>? participants = participantsRaw is List
                  ? participantsRaw.map((e) => e.toString()).toList()
                  : memberIdsRaw is List
                      ? memberIdsRaw.map((e) => e.toString()).toList()
                      : null;
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: EmptyStatePanel(
                            icon: Icons.cloud_off_outlined,
                            title: 'Messages couldn’t load',
                            message:
                                'Check your connection and try opening this thread again. '
                                'If it keeps happening, pull to refresh from the inbox.',
                          ),
                        ),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return Expanded(
                      child: Center(
                        child: CircularProgressIndicator(color: PLDesign.primary),
                      ),
                    );
                  }

                  final docs = snap.data!.docs;

                  final displayDocs = widget.flaggedOnly
                      ? docs.where((d) {
                          final m = d.data();
                          final f = m['legalFlag'];
                          return f != null && f.toString().trim().isNotEmpty;
                        }).toList()
                      : docs;

                  if (!_markedReadOnce && docs.isNotEmpty && !isAttorney) {
                    _markedReadOnce = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      CaseMessagingService.markInboundRead(
                        caseId: widget.caseId,
                        conversationId: widget.conversationId,
                        readerUid: uid,
                      );
                    });
                  }

                  final counts = _summaryFromDocs(displayDocs);
                  final summaryLines = _summaryLines(counts);
                  final hasOtherUser = hasCoParent(participants, uid);

                  return Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    if (summaryLines.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: PLDesign.card,
                          borderRadius: PLDesign.r16,
                          border: Border.all(color: PLDesign.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Flagged messages (record)',
                              style: PLDesign.sectionTitle.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            ...summaryLines.map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: PLDesign.body.copyWith(
                                        color: PLDesign.textMuted,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        line,
                                        style: PLDesign.body.copyWith(
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: isAttorney
                                ? _generateAttorneyBrief
                                : (_courtSummaryBusy ? null : _generateAiCourtSummary),
                            style: FilledButton.styleFrom(
                              backgroundColor: PLDesign.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: _courtSummaryBusy && !isAttorney
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.account_balance, size: 20),
                            label: Text(
                              isAttorney
                                  ? 'Generate attorney brief'
                                  : 'Generate Court Summary',
                            ),
                          ),
                          if (!isAttorney) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed:
                                  _courtSummaryBusy ? null : _saveExtendedCaseSummary,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PLDesign.textPrimary,
                                side: const BorderSide(color: PLDesign.border),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(context.tTone('saveExtendedRecordToCase')),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isAttorney && showWarning)
                      Container(
                        color: PLDesign.danger.withValues(alpha: 0.12),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning, color: PLDesign.danger),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'AI review: this message may escalate conflict. You can use the suggested wording or send as written.',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: _sendDespiteWarning,
                                  child: Text(context.tTone('sendAsWritten')),
                                ),
                                FilledButton(
                                  onPressed: _applyToneSuggestion,
                                  child: Text(context.tTone('useAiSuggestion')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (!isAttorney && !hasOtherUser)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 6),
                        child: Text(
                          'No co-parent connected yet',
                          style: PLDesign.caption.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    Expanded(
                      child: displayDocs.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  widget.flaggedOnly
                                      ? 'No flagged messages in this thread.'
                                      : isAttorney
                                          ? 'No messages in this record.'
                                          : 'No messages yet — conversations here are securely recorded',
                                  textAlign: TextAlign.center,
                                  style: PLDesign.body.copyWith(
                                    color: PLDesign.textMuted,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              itemCount: displayDocs.length,
                              itemBuilder: (_, i) => _bubble(
                                displayDocs[i],
                                readOnly: isAttorney,
                              ),
                            ),
                    ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          if (!isAttorney)
            SafeArea(
              child: Material(
                color: PLDesign.surface,
                elevation: 8,
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _conversationDocStream,
                  builder: (context, convSnap) {
                    final showTyping = _peerTypingFresh(convSnap.data?.data());
                    return Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: PLDesign.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Messages are immutable once sent — long-press a bubble to mark for court.',
                        style: PLDesign.caption.copyWith(
                          fontSize: 11,
                          color: PLDesign.textMuted,
                        ),
                      ),
                      if (showTyping) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Co-parent is typing…',
                          style: PLDesign.caption.copyWith(
                            fontSize: 12,
                            color: PLDesign.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              minLines: 1,
                              maxLines: 5,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              autocorrect: true,
                              enableSuggestions: true,
                              spellCheckConfiguration:
                                  const SpellCheckConfiguration(),
                              style: const TextStyle(color: PLDesign.textPrimary),
                              decoration: InputDecoration(
                                hintText:
                                    'Write your message (stored as a legal record)...',
                                hintStyle: TextStyle(
                                  color:
                                      PLDesign.textMuted.withValues(alpha: 0.75),
                                ),
                                filled: true,
                                fillColor: PLDesign.card,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: PLDesign.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: PLDesign.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: PLDesign.primary.withValues(alpha: 0.8),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Material(
                            color: PLDesign.primary,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: (sending || _toneClassifying) ? null : send,
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: (sending || _toneClassifying)
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.arrow_upward_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
                  },
                ),
              ),
            )
          else
            SafeArea(
              child: Material(
                color: PLDesign.surface,
                elevation: 8,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: PLDesign.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, color: PLDesign.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Counsel read-only: you cannot compose, edit, or tag messages.',
                          style: PLDesign.caption.copyWith(
                            color: PLDesign.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
