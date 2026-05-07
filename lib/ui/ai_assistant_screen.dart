import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/ai_service.dart';

/// In-app assistant: app help, case-aware analysis, and neutral guidance.
/// Intent is determined automatically on the server (no visible “modes”).
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _ChatTurn {
  _ChatTurn({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatTurn> _turns = [];
  bool _busy = false;

  static const String _hint =
      'Ask about your case, messages, or how to use the app...';

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return base.copyWith(
      p: PLDesign.body.copyWith(color: PLDesign.textPrimary, height: 1.42),
      h1: PLDesign.heroTitle.copyWith(fontSize: 20, color: PLDesign.textPrimary),
      h2: PLDesign.sectionTitle.copyWith(fontSize: 17, color: PLDesign.textPrimary),
      h3: PLDesign.sectionTitle.copyWith(fontSize: 15, color: PLDesign.textPrimary),
      listBullet: PLDesign.body.copyWith(color: PLDesign.textMuted),
      strong: PLDesign.sectionTitle.copyWith(fontSize: 14, color: PLDesign.primary),
      code: PLDesign.body.copyWith(
        fontFamily: 'monospace',
        color: PLDesign.textMuted,
        backgroundColor: PLDesign.surface,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _submit() async {
    final q = _input.text.trim();
    if (q.isEmpty || _busy) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _turns.add(_ChatTurn(fromUser: true, text: q));
      _busy = true;
    });
    _input.clear();
    _scrollToBottom();

    final caseCtx = context.read<CaseContext>();
    final cid = caseCtx.caseId?.trim();
    final caseIdArg = (cid != null && cid.isNotEmpty) ? cid : null;

    try {
      final reply = await AiService.askSmartAssistant(q, caseId: caseIdArg);
      if (!mounted) return;
      setState(() => _turns.add(_ChatTurn(fromUser: false, text: reply)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AiService.userFacingMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToBottom();
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Assistant'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Answers may use your linked case when helpful. This is not legal advice.',
              style: PLDesign.caption.copyWith(color: PLDesign.textMuted, height: 1.35),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _turns.length + 1,
              itemBuilder: (context, i) {
                if (i == _turns.length) {
                  return const SizedBox(height: 8);
                }

                final t = _turns[i];
                final bg = t.fromUser ? PLDesign.primary.withValues(alpha: 0.15) : PLDesign.card;
                final radius = BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(t.fromUser ? 18 : 6),
                  bottomRight: Radius.circular(t.fromUser ? 6 : 18),
                );
                final align = t.fromUser ? Alignment.centerRight : Alignment.centerLeft;
                final maxW = MediaQuery.sizeOf(context).width * 0.9;

                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    constraints: BoxConstraints(maxWidth: maxW),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: radius,
                      border: Border.all(color: PLDesign.border.withValues(alpha: 0.5)),
                      boxShadow: PLDesign.softShadow,
                    ),
                    child: t.fromUser
                        ? Text(t.text, style: PLDesign.body.copyWith(height: 1.35))
                        : MarkdownBody(
                            data: t.text,
                            selectable: true,
                            styleSheet: _markdownStyle(context),
                          ),
                  ),
                );
              },
            ),
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: PLDesign.primary),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.paddingOf(context).bottom),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PLDesign.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: PLDesign.border),
                boxShadow: PLDesign.softShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      style: PLDesign.body,
                      decoration: InputDecoration(
                        hintText: _hint,
                        hintStyle: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : _submit,
                    icon: Icon(Icons.send_rounded, color: _busy ? PLDesign.textMuted : PLDesign.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
