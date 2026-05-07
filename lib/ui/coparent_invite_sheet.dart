import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:share_plus/share_plus.dart';

import '../design/design.dart';
import '../services/coparent_invite_code_service.dart';
import 'invite_phone_sheet.dart';

Future<void> showCoparentInviteSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _CoparentInviteSheet(),
  );
}

class _CoparentInviteSheet extends StatefulWidget {
  const _CoparentInviteSheet();

  @override
  State<_CoparentInviteSheet> createState() => _CoparentInviteSheetState();
}

class _CoparentInviteSheetState extends State<_CoparentInviteSheet> {
  bool _loading = true;
  String? _error;
  CoparentInviteLinkResult? _result;

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await CoparentInviteCodeService.createInviteCode();
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<String> _inviterShortNameResolved() async {
    final u = FirebaseAuth.instance.currentUser;
    final d = u?.displayName?.trim();
    if (d != null && d.isNotEmpty) {
      return d.split(RegExp(r'\s+')).first;
    }
    if (u == null) return 'A parent';
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      final fn = doc.data()?['firstName']?.toString().trim() ?? '';
      if (fn.isNotEmpty) return fn;
    } catch (_) {}
    return 'A parent';
  }

  Future<void> _share() async {
    final r = _result;
    if (r == null ||
        r.token.isEmpty ||
        r.universalLink.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invite link is not ready. Pull to retry or close and open again.',
          ),
        ),
      );
      return;
    }
    final name = await _inviterShortNameResolved();
    final body = CoparentInviteCodeService.shareMessageForInviter(
      inviterFirstName: name,
      invite: r,
    );
    await SharePlus.instance.share(ShareParams(text: body));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
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
                Text(
                  'Invite Co-Parent',
                  style: PLDesign.sectionTitle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share a secure link. Recipients tap once and ParentLedger opens—no URLs to read aloud.',
                  style: PLDesign.caption.copyWith(
                    color: PLDesign.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _error!,
                        style: PLDesign.body.copyWith(color: PLDesign.danger),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _create,
                        child: const Text('Try again'),
                      ),
                    ],
                  )
                else if (_result != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PLDesign.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: PLDesign.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, color: PLDesign.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Expires in 48 hours · Opens in ParentLedger automatically',
                            style: PLDesign.caption.copyWith(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share_rounded),
                    label: Text(context.tTone('sendInvite_neutral')),
                    style: FilledButton.styleFrom(
                      backgroundColor: PLDesign.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showInvitePhoneSheet(context, role: 'coparent');
                  },
                  child: Text(
                    'Invite by phone instead',
                    style: PLDesign.caption.copyWith(
                      color: PLDesign.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
