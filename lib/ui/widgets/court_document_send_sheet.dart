import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parentledger/design/design.dart';
import 'package:parentledger/models/legal_export_models.dart';
import 'package:parentledger/services/court_document_email_service.dart';

enum CourtRecipientRole {
  attorney,
  judge,
}

extension on CourtRecipientRole {
  String get apiValue =>
      this == CourtRecipientRole.attorney ? 'attorney' : 'judge';

  String get label =>
      this == CourtRecipientRole.attorney ? 'Attorney' : 'Judge';

  String get prefsKey => this == CourtRecipientRole.attorney
      ? 'court_pack_last_attorney_email'
      : 'court_pack_last_judge_email';
}

Future<bool?> showCourtDocumentSendSheet(
  BuildContext context, {
  required ExportDocument document,
  required String plainTextBody,
  required CourtRecipientRole initialRole,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CourtDocumentSendSheet(
      document: document,
      plainTextBody: plainTextBody,
      initialRole: initialRole,
    ),
  );
}

class _CourtDocumentSendSheet extends StatefulWidget {
  const _CourtDocumentSendSheet({
    required this.document,
    required this.plainTextBody,
    required this.initialRole,
  });

  final ExportDocument document;
  final String plainTextBody;
  final CourtRecipientRole initialRole;

  @override
  State<_CourtDocumentSendSheet> createState() =>
      _CourtDocumentSendSheetState();
}

class _CourtDocumentSendSheetState extends State<_CourtDocumentSendSheet> {
  final _emailFocus = FocusNode();
  final _noteFocus = FocusNode();
  late CourtRecipientRole _role;
  final _emailController = TextEditingController();
  final _noteController = TextEditingController();
  bool _loading = false;
  String? _emailError;
  bool get _canSend => _emailController.text.trim().isNotEmpty && !_loading;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_role.prefsKey);
    if (!mounted) return;
    if (saved != null && saved.isNotEmpty) {
      setState(() => _emailController.text = saved);
    }
  }

  Future<void> _persistEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_role.prefsKey, email.trim());
  }

  bool _validEmail(String v) {
    final trimmed = v.trim();
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed);
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    setState(() => _emailError = null);

    if (!_validEmail(email)) {
      setState(() => _emailError = 'Enter a valid email address.');
      return;
    }

    setState(() => _loading = true);
    HapticFeedback.lightImpact();

    try {
      await CourtDocumentEmailService.send(
        recipientEmail: email,
        recipientRole: _role.apiValue,
        caseId: widget.document.caseId,
        documentTitle: widget.document.title,
        documentPlainText: widget.plainTextBody,
        optionalNote: _noteController.text,
      );
      await _persistEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document sent successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: PLDesign.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _noteFocus.dispose();
    _emailController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [PLDesign.bgTop, PLDesign.bgBottom],
          ),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(PLDesign.radiusL)),
          border: Border.all(color: PLDesign.border),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PLDesign.s24,
            PLDesign.s12,
            PLDesign.s24,
            PLDesign.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PLDesign.textMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: PLDesign.s20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: PLDesign.aiSurface,
                    child: const Icon(Icons.gavel_rounded,
                        color: PLDesign.premiumGold, size: 26),
                  ),
                  const SizedBox(width: PLDesign.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send court document',
                          style: PLDesign.sectionTitle.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Delivered from ParentLedger — your mail app stays closed.',
                          style: PLDesign.body.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PLDesign.s24),
              SegmentedButton<CourtRecipientRole>(
                segments: [
                  ButtonSegment(
                    value: CourtRecipientRole.attorney,
                    label: Text(context.tTone('attorney')),
                    icon: Icon(Icons.balance_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: CourtRecipientRole.judge,
                    label: Text(context.tTone('judge')),
                    icon: Icon(Icons.account_balance_rounded, size: 18),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (s) async {
                  final next = s.first;
                  setState(() => _role = next);
                  final prefs = await SharedPreferences.getInstance();
                  final saved = prefs.getString(next.prefsKey);
                  if (!mounted) return;
                  if (saved != null && saved.isNotEmpty) {
                    _emailController.text = saved;
                  }
                },
              ),
              const SizedBox(height: PLDesign.s16),
              TextField(
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onChanged: (_) => setState(() => _emailError = null),
                style: const TextStyle(color: PLDesign.textPrimary),
                decoration: InputDecoration(
                  labelText: '${_role.label} email',
                  labelStyle: const TextStyle(color: PLDesign.textMuted),
                  errorText: _emailError,
                  filled: true,
                  fillColor: PLDesign.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: PLDesign.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: PLDesign.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: PLDesign.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: PLDesign.s12),
              TextField(
                controller: _noteController,
                focusNode: _noteFocus,
                maxLines: 3,
                maxLength: 500,
                style: const TextStyle(color: PLDesign.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Optional note (included in delivery)',
                  labelStyle: const TextStyle(color: PLDesign.textMuted),
                  filled: true,
                  fillColor: PLDesign.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: PLDesign.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: PLDesign.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: PLDesign.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: PLDesign.s20),
              DecoratedBox(
                decoration: PLDesign.alertWarning,
                child: Padding(
                  padding: const EdgeInsets.all(PLDesign.s12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: PLDesign.warning.withValues(alpha: 0.9)),
                      const SizedBox(width: PLDesign.s8),
                      Expanded(
                        child: Text(
                          'Recipient will receive a notice that your court packet is ready, with the full document text.',
                          style: PLDesign.body.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: PLDesign.s20),
              SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: PLDesign.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: PLDesign.softShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _canSend ? _send : null,
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded,
                                      color: Colors.white, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Send securely',
                                    style: PLDesign.buttonText.copyWith(
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PLDesign.s8),
              TextButton(
                onPressed:
                    _loading ? null : () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: PLDesign.secondaryButtonText.copyWith(
                    color: PLDesign.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
