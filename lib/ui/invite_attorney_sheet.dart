import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../design/design.dart';
import '../services/invite_service.dart';

/// Creates a pending case invite with [role] attorney and exposes path-only invite URLs.
Future<void> showInviteAttorneySheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _InviteAttorneyBody(),
  );
}

class _InviteAttorneyBody extends StatefulWidget {
  const _InviteAttorneyBody();

  @override
  State<_InviteAttorneyBody> createState() => _InviteAttorneyBodyState();
}

class _InviteAttorneyBodyState extends State<_InviteAttorneyBody> {
  bool _working = false;
  AttorneyInviteLinks? _links;
  String? _error;
  final _recipientEmail = TextEditingController();

  String _shareBody(String universalLink) =>
      '''Attorney invitation — ParentLedger (read-only case access)

Tap to open in the app:
$universalLink
''';

  @override
  void dispose() {
    _recipientEmail.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final caseId = userDoc.data()?['caseId'] as String?;
      if (caseId == null) {
        throw StateError('Link a case first (finish workspace setup).');
      }
      final email = _recipientEmail.text.trim().toLowerCase();
      if (email.isEmpty || !email.contains('@')) {
        throw StateError('Enter attorney email before generating invite.');
      }
      final links = await InviteService.createAttorneyInvite(
        caseId: caseId,
        fromUserId: uid,
        intendedRecipientEmail: email,
      );
      if (links.token.isEmpty || links.universalLink.isEmpty) {
        throw StateError('Invite generation failed: missing token or universal link.');
      }
      if (!mounted) return;
      setState(() {
        _links = links;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _shareUniversalLink() async {
    final links = _links;
    if (links == null ||
        links.token.isEmpty ||
        links.universalLink.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite link is not ready. Generate the invite first.'),
        ),
      );
      return;
    }
    await Share.share(_shareBody(links.universalLink));
  }

  Future<void> _copyUniversalLink() async {
    final links = _links;
    if (links == null ||
        links.token.isEmpty ||
        links.universalLink.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite link is not ready.')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: _shareBody(links.universalLink)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite message copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: PLDesign.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PLDesign.textMuted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Invite attorney',
                    style: PLDesign.sectionTitle.copyWith(fontSize: 20)),
                const SizedBox(height: 10),
                Text(
                  'Counsel gets read-only access to this case. Share the secure link—recipients tap once in Messages or email.',
                  style: PLDesign.caption.copyWith(height: 1.35),
                ),
                const SizedBox(height: 20),
                if (_links == null) ...[
                  TextField(
                    controller: _recipientEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Attorney email',
                      hintText: 'name@lawfirm.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style:
                            PLDesign.caption.copyWith(color: PLDesign.danger),
                      ),
                    ),
                  FilledButton(
                    onPressed: _working ? null : _generate,
                    child: _working
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tTone('generateInviteLink')),
                  ),
                ] else ...[
                  Text('Invite token', style: PLDesign.caption),
                  const SizedBox(height: 8),
                  SelectableText(
                    _links!.token,
                    style: PLDesign.body.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    _links!.universalLink,
                    style: PLDesign.caption.copyWith(
                      color: PLDesign.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _shareUniversalLink,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Share Invite'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _copyUniversalLink,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy Invite Message'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ask your attorney to tap this link on mobile. ParentLedger opens directly to accept.',
                    style: PLDesign.caption.copyWith(
                      color: PLDesign.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tTone('close')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
