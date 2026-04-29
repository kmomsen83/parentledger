import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';
import '../models/negotiation_proposal.dart';
import '../services/proposal_service.dart';
import '../services/timeline_actor_resolver.dart';
import 'proposal_resolution_screen.dart';

class ActiveNegotiationScreen extends StatefulWidget {
  const ActiveNegotiationScreen({
    super.key,
    required this.proposalId,
  });

  final String proposalId;

  @override
  State<ActiveNegotiationScreen> createState() =>
      _ActiveNegotiationScreenState();
}

class _ActiveNegotiationScreenState extends State<ActiveNegotiationScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _opening = false;
  bool _triedAutoStart = false;

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ensureOpen(NegotiationProposal? p) async {
    if (p == null || _opening || _triedAutoStart) return;
    if (p.status != ProposalStatuses.pending) return;
    _triedAutoStart = true;
    _opening = true;
    try {
      await ProposalService.startNegotiation(p);
    } catch (_) {
      // Another participant may have started; continue.
    } finally {
      _opening = false;
    }
  }

  Future<void> _send(NegotiationProposal p) async {
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    try {
      await ProposalService.sendMessage(p: p, text: text);
      _composer.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message not sent: $e')),
      );
    }
  }

  Future<void> _accept(NegotiationProposal p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: const Text('Accept', style: TextStyle(color: PLDesign.textPrimary)),
        content: Text(
          'Accept the current terms (revision ${p.proposedRevision}) and move to the agreement record.',
          style: PLDesign.body.copyWith(color: PLDesign.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ProposalService.accept(p);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ProposalResolutionScreen(proposalId: widget.proposalId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: $e')),
      );
    }
  }

  Future<void> _reject(NegotiationProposal p) async {
    final reason = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: const Text('Reject', style: TextStyle(color: PLDesign.textPrimary)),
        content: TextField(
          controller: reason,
          maxLines: 3,
          style: const TextStyle(color: PLDesign.textPrimary),
          decoration: InputDecoration(
            hintText: 'Optional reason',
            hintStyle: TextStyle(color: PLDesign.textMuted.withValues(alpha: 0.8)),
            filled: true,
            fillColor: PLDesign.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: PLDesign.danger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    try {
      await ProposalService.reject(p, reason: reason.text);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e')),
      );
    }
  }

  Future<void> _suggestTerms(NegotiationProposal p) async {
    final note = TextEditingController();
    DateTime? date;
    TimeOfDay? time;
    final loc = TextEditingController();
    final amount = TextEditingController();
    final notes = TextEditingController();

    switch (p.kind) {
      case 'schedule':
        final raw = p.proposedData['scheduledTime']?.toString();
        final parsed = raw != null ? DateTime.tryParse(raw) : null;
        if (parsed != null) {
          date = DateTime(parsed.year, parsed.month, parsed.day);
          time = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
        }
        loc.text = (p.proposedData['locationName'] ?? '').toString();
        notes.text = (p.proposedData['notes'] ?? '').toString();
        break;
      case 'expense':
        final a = p.proposedData['amount'];
        if (a != null) amount.text = a is num ? a.toString() : a.toString();
        final rd = p.proposedData['requestedDate']?.toString();
        final pd = rd != null ? DateTime.tryParse(rd) : null;
        if (pd != null) date = DateTime(pd.year, pd.month, pd.day);
        notes.text = (p.proposedData['notes'] ?? '').toString();
        break;
      case 'location':
        loc.text = (p.proposedData['locationName'] ?? '').toString();
        final rd = p.proposedData['requestedDate']?.toString();
        final pd = rd != null ? DateTime.tryParse(rd) : null;
        if (pd != null) date = DateTime(pd.year, pd.month, pd.day);
        notes.text = (p.proposedData['notes'] ?? '').toString();
        break;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PLDesign.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Propose revised terms',
                      style: PLDesign.sectionTitle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This creates a new revision and is recorded in the case ledger.',
                      style: PLDesign.caption.copyWith(color: PLDesign.textMuted),
                    ),
                    const SizedBox(height: 16),
                    if (p.kind == 'schedule') ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Date', style: TextStyle(color: PLDesign.textMuted, fontSize: 12)),
                        subtitle: Text(
                          date == null ? 'Select' : DateFormat.yMMMd().format(date!),
                          style: const TextStyle(color: PLDesign.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.calendar_today_rounded, color: PLDesign.primary),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: date ?? DateTime.now(),
                            firstDate: DateTime(DateTime.now().year - 2),
                            lastDate: DateTime(DateTime.now().year + 2, 12, 31),
                            builder: (c, w) => Theme(
                              data: Theme.of(c).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: PLDesign.primary,
                                  surface: PLDesign.surface,
                                ),
                              ),
                              child: w ?? const SizedBox.shrink(),
                            ),
                          );
                          if (d != null) setModal(() => date = d);
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Time', style: TextStyle(color: PLDesign.textMuted, fontSize: 12)),
                        subtitle: Text(
                          time == null ? 'Select' : time!.format(context),
                          style: const TextStyle(color: PLDesign.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.schedule_rounded, color: PLDesign.primary),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: time ?? const TimeOfDay(hour: 17, minute: 0),
                            builder: (c, w) => Theme(
                              data: Theme.of(c).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: PLDesign.primary,
                                  surface: PLDesign.surface,
                                ),
                              ),
                              child: w ?? const SizedBox.shrink(),
                            ),
                          );
                          if (t != null) setModal(() => time = t);
                        },
                      ),
                      TextField(
                        controller: loc,
                        style: const TextStyle(color: PLDesign.textPrimary),
                        decoration: _fieldDeco('Location'),
                      ),
                    ],
                    if (p.kind == 'expense') ...[
                      TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: PLDesign.textPrimary),
                        decoration: _fieldDeco('Amount (USD)'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Request date', style: TextStyle(color: PLDesign.textMuted, fontSize: 12)),
                        subtitle: Text(
                          date == null ? 'Select' : DateFormat.yMMMd().format(date!),
                          style: const TextStyle(color: PLDesign.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: date ?? DateTime.now(),
                            firstDate: DateTime(DateTime.now().year - 2),
                            lastDate: DateTime(DateTime.now().year + 2, 12, 31),
                            builder: (c, w) => Theme(
                              data: Theme.of(c).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: PLDesign.primary,
                                  surface: PLDesign.surface,
                                ),
                              ),
                              child: w ?? const SizedBox.shrink(),
                            ),
                          );
                          if (d != null) setModal(() => date = d);
                        },
                      ),
                    ],
                    if (p.kind == 'location') ...[
                      TextField(
                        controller: loc,
                        style: const TextStyle(color: PLDesign.textPrimary),
                        decoration: _fieldDeco('Location name'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Date', style: TextStyle(color: PLDesign.textMuted, fontSize: 12)),
                        subtitle: Text(
                          date == null ? 'Select' : DateFormat.yMMMd().format(date!),
                          style: const TextStyle(color: PLDesign.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: date ?? DateTime.now(),
                            firstDate: DateTime(DateTime.now().year - 2),
                            lastDate: DateTime(DateTime.now().year + 2, 12, 31),
                            builder: (c, w) => Theme(
                              data: Theme.of(c).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: PLDesign.primary,
                                  surface: PLDesign.surface,
                                ),
                              ),
                              child: w ?? const SizedBox.shrink(),
                            ),
                          );
                          if (d != null) setModal(() => date = d);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notes,
                      maxLines: 3,
                      style: const TextStyle(color: PLDesign.textPrimary),
                      decoration: _fieldDeco('Notes (optional)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: note,
                      maxLines: 2,
                      style: const TextStyle(color: PLDesign.textPrimary),
                      decoration: _fieldDeco('Summary for timeline (one line)'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save revision'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (saved != true || !mounted) return;

    Map<String, dynamic> next = Map<String, dynamic>.from(p.proposedData);
    String summaryLine;

    try {
      switch (p.kind) {
        case 'schedule':
          if (date == null || time == null) {
            throw StateError('Choose a date and time');
          }
          final at = DateTime(date!.year, date!.month, date!.day, time!.hour, time!.minute);
          final location = loc.text.trim();
          if (location.isEmpty) throw StateError('Location is required');
          next = <String, dynamic>{
            'scheduledTime': at.toIso8601String(),
            'locationName': location,
            'exchangeType': 'proposed',
            if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
          };
          summaryLine = note.text.trim().isNotEmpty
              ? note.text.trim()
              : 'Schedule revision · ${DateFormat.yMMMd().add_jm().format(at)} · $location';
          break;
        case 'expense':
          final amt = double.tryParse(amount.text.trim());
          if (amt == null || amt <= 0) throw StateError('Enter a valid amount');
          if (date == null) throw StateError('Choose a date');
          next = <String, dynamic>{
            'amount': amt,
            'requestedDate': DateTime(date!.year, date!.month, date!.day).toIso8601String(),
            if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
          };
          summaryLine = note.text.trim().isNotEmpty
              ? note.text.trim()
              : 'Expense revision · \$${amt.toStringAsFixed(2)}';
          break;
        case 'location':
          final ln = loc.text.trim();
          if (ln.isEmpty) throw StateError('Location is required');
          if (date == null) throw StateError('Choose a date');
          next = <String, dynamic>{
            'locationName': ln,
            'requestedDate': DateTime(date!.year, date!.month, date!.day).toIso8601String(),
            if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
          };
          summaryLine = note.text.trim().isNotEmpty
              ? note.text.trim()
              : 'Location revision · $ln';
          break;
        default:
          throw StateError('Unsupported proposal type');
      }

      await ProposalService.updateProposedTerms(
        p: p,
        newProposedData: next,
        summaryNote: summaryLine,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terms updated and logged')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  InputDecoration _fieldDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: PLDesign.textMuted.withValues(alpha: 0.85)),
      filled: true,
      fillColor: PLDesign.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Negotiation'),
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<NegotiationProposal?>(
        stream: ProposalService.watchProposal(widget.proposalId),
        builder: (context, propSnap) {
          final p = propSnap.data;
          if (p != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _ensureOpen(p));
          }

          if (propSnap.connectionState == ConnectionState.waiting && p == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (p == null) {
            return Center(
              child: Text(
                'Proposal unavailable.',
                style: PLDesign.body.copyWith(color: PLDesign.textMuted),
              ),
            );
          }

          if (p.isTerminal && p.status != ProposalStatuses.accepted) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  p.status == ProposalStatuses.rejected
                      ? 'This negotiation was rejected.'
                      : 'This record is closed.',
                  textAlign: TextAlign.center,
                  style: PLDesign.body.copyWith(color: PLDesign.textMuted),
                ),
              ),
            );
          }

          if (p.status == ProposalStatuses.accepted) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'This proposal was accepted.',
                      textAlign: TextAlign.center,
                      style: PLDesign.sectionTitle.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ProposalResolutionScreen(proposalId: widget.proposalId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.description_rounded),
                      label: const Text('Open agreement record'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PLDesign.timelineTitle,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: PLDesign.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: PLDesign.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Revision ${p.proposedRevision}',
                        style: const TextStyle(
                          color: PLDesign.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ProposalMessage>>(
                  stream: ProposalService.watchMessages(widget.proposalId),
                  builder: (context, msgSnap) {
                    final messages = msgSnap.data ?? [];
                    if (messages.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scroll.hasClients) {
                          _scroll.jumpTo(_scroll.position.maxScrollExtent);
                        }
                      });
                    }

                    if (messages.isEmpty && msgSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forum_outlined, size: 48, color: PLDesign.textMuted.withValues(alpha: 0.5)),
                              const SizedBox(height: 14),
                              Text(
                                'No messages yet',
                                style: PLDesign.sectionTitle.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Use a neutral, factual tone. Messages cannot be edited after they are sent.',
                                textAlign: TextAlign.center,
                                style: PLDesign.caption.copyWith(color: PLDesign.textMuted, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final ids = messages.map((m) => m.senderId).toSet();
                    return FutureBuilder<Map<String, TimelineActor>>(
                      future: TimelineActor.loadMany(ids),
                      builder: (context, actorSnap) {
                        final actors = actorSnap.data ?? {};
                        return ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: messages.length,
                          itemBuilder: (context, i) {
                            final m = messages[i];
                            final mine = m.senderId == uid;
                            final name = actors[m.senderId]?.fullName ?? 'Participant';
                            final bubble = Container(
                              margin: EdgeInsets.only(
                                bottom: 12,
                                left: mine ? 36 : 0,
                                right: mine ? 0 : 36,
                              ),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: mine
                                    ? PLDesign.primary.withValues(alpha: 0.22)
                                    : PLDesign.card,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(mine ? 16 : 4),
                                  bottomRight: Radius.circular(mine ? 4 : 16),
                                ),
                                border: Border.all(
                                  color: mine
                                      ? PLDesign.primary.withValues(alpha: 0.35)
                                      : PLDesign.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            color: mine ? PLDesign.primary : PLDesign.textMuted,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        DateFormat.jm().format(m.createdAt.toLocal()),
                                        style: PLDesign.caption.copyWith(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    m.text,
                                    style: PLDesign.body.copyWith(height: 1.35),
                                  ),
                                ],
                              ),
                            );
                            return bubble;
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              if (p.canNegotiate)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _suggestTerms(p),
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('Suggest new terms'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _reject(p),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Reject'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _accept(p),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Accept'),
                      ),
                    ],
                  ),
                ),
              if (p.canSendMessage)
                Container(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 8,
                    bottom: MediaQuery.paddingOf(context).bottom + 8,
                  ),
                  decoration: BoxDecoration(
                    color: PLDesign.surface,
                    border: Border(top: BorderSide(color: PLDesign.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _composer,
                          minLines: 1,
                          maxLines: 5,
                          style: const TextStyle(color: PLDesign.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Message',
                            hintStyle: TextStyle(color: PLDesign.textMuted.withValues(alpha: 0.85)),
                            filled: true,
                            fillColor: PLDesign.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: PLDesign.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _send(p),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => _send(p),
                        icon: const Icon(Icons.send_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: PLDesign.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
