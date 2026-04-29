import 'package:parentledger/l10n/context_l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart'
    show
        Contact,
        ContactProperty,
        FlutterContacts,
        PermissionStatus,
        PermissionType;

import '../design/design.dart';
import 'widgets/us_phone_input_formatter.dart';

/// Phone-only invite flow (no email). Used for co-parent invites.
Future<void> showInvitePhoneSheet(
  BuildContext context, {
  required String role,
  String? initialFormattedPhone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _InvitePhoneSheet(
      role: role,
      initialFormattedPhone: initialFormattedPhone,
    ),
  );
}

class _InvitePhoneSheet extends StatefulWidget {
  const _InvitePhoneSheet({
    required this.role,
    this.initialFormattedPhone,
  });

  final String role;
  final String? initialFormattedPhone;

  @override
  State<_InvitePhoneSheet> createState() => _InvitePhoneSheetState();
}

class _InvitePhoneSheetState extends State<_InvitePhoneSheet> {
  late final TextEditingController _phone;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.initialFormattedPhone ?? '');
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _title => 'Invite Co-Parent';

  Future<void> _importContact() async {
    try {
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tTone('contactsPermissionIsRequiredTo')),
          ),
        );
        return;
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ContactPickSheet(
          onPick: (rawNumber) {
            final digits = rawNumber.replaceAll(RegExp(r'\D'), '');
            var nsn = digits;
            if (nsn.length == 11 && nsn.startsWith('1')) {
              nsn = nsn.substring(1);
            }
            if (nsn.length == 10) {
              setState(() {
                _phone.text = _formatFromNational(nsn);
                _phone.selection = TextSelection.collapsed(
                  offset: _phone.text.length,
                );
              });
            }
            Navigator.pop(ctx);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open contacts: $e')),
      );
    }
  }

  String _formatFromNational(String tenDigits) {
    final d = tenDigits;
    return '+1 (${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6)}';
  }

  Future<void> _send() async {
    final e164 = normalizeUsPhoneToE164(_phone.text);
    if (e164 == null) return;

    setState(() => _sending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Sign in required');
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('createCaseInvite');
      await callable.call(<String, dynamic>{
        'toPhone': e164,
        'role': widget.role,
        'intendedRecipientPhone': e164,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('inviteSent'))),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not send invite.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final valid = isValidUsPhoneFormatted(_phone.text);

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
                Text(_title,
                    style: PLDesign.sectionTitle.copyWith(fontSize: 20)),
                const SizedBox(height: 20),
                Text(
                  'Phone Number',
                  style: PLDesign.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: PLDesign.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autocorrect: false,
                  style: PLDesign.body.copyWith(
                    fontSize: 18,
                    color: PLDesign.textPrimary,
                  ),
                  inputFormatters: [UsPhoneInputFormatter()],
                  decoration: InputDecoration(
                    hintText: '+1 (555) 555-5555',
                    filled: true,
                    fillColor: PLDesign.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: PLDesign.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: PLDesign.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: PLDesign.primary, width: 1.5),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _sending ? null : _importContact,
                  icon: const Icon(Icons.import_contacts_rounded, size: 22),
                  label: Text(context.tTone('importFromContacts')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PLDesign.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: PLDesign.border),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: (_sending || !valid) ? null : _send,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: PLDesign.primary,
                  ),
                  child: _sending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tTone('sendInvite')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactPickSheet extends StatefulWidget {
  const _ContactPickSheet({required this.onPick});

  final void Function(String rawPhone) onPick;

  @override
  State<_ContactPickSheet> createState() => _ContactPickSheetState();
}

class _ContactPickSheetState extends State<_ContactPickSheet> {
  final _search = TextEditingController();
  List<Contact> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
        limit: 800,
      );
      if (mounted) {
        setState(() {
          _all = list.where((c) => c.phones.isNotEmpty).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = _all
        .where((c) {
          if (q.isEmpty) return true;
          final name = (c.displayName ?? '').toLowerCase();
          return name.contains(q);
        })
        .take(80)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search contacts',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 360,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      final phone = c.phones.first.number.trim();
                      if (phone.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return ListTile(
                        title: Text(
                          c.displayName ?? 'Contact',
                          style: PLDesign.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          phone,
                          style: PLDesign.caption,
                        ),
                        onTap: () => widget.onPick(phone),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
