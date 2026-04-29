import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/case_messaging_service.dart';
import '../services/case_participant_service.dart';
import '../services/case_thread_catalog.dart';
import 'conversation_thread_screen.dart';

/// Case file: ordered list of legal message threads (not a single chat).
class MessagesInboxScreen extends StatefulWidget {
  const MessagesInboxScreen({super.key});

  static String _formatListTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (now.difference(dt).inDays < 7) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1];
    }
    return '${dt.month}/${dt.day}/${dt.year.toString().substring(2)}';
  }

  static String _displayNameFromUserDoc(Map<String, dynamic>? d) {
    if (d == null) return '';
    final dn = (d['displayName'] ?? '').toString().trim();
    if (dn.isNotEmpty) return dn;
    final fn = (d['firstName'] ?? '').toString().trim();
    final ln = (d['lastName'] ?? '').toString().trim();
    final full = '$fn $ln'.trim();
    if (full.isNotEmpty) return full;
    final em = (d['email'] ?? '').toString().trim();
    if (em.isNotEmpty) return em.split('@').first;
    return '';
  }

  static void openThread(
    BuildContext context, {
    required String caseId,
    required String conversationId,
    required String title,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ConversationThreadScreen(
          title: title,
          caseId: caseId,
          conversationId: conversationId,
        ),
      ),
    );
  }

  static String _rowTitle({
    required String conversationId,
    required Map<String, dynamic> conv,
    required String caseLabel,
    required String coparentName,
  }) {
    if (CaseThreadCatalog.isStandardThread(conversationId)) {
      return CaseThreadCatalog.threadTitle(conversationId, conv);
    }
    final t = (conv['title'] ?? '').toString().trim();
    if (coparentName.isNotEmpty) return coparentName;
    if (t.isNotEmpty && t != 'Case discussion') return t;
    if (caseLabel.isNotEmpty) return caseLabel;
    return 'Messages';
  }

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen> {
  String? _boundCaseId;
  Future<void>? _threadsReady;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final caseId = context.watch<CaseContext>().caseId;
    if (caseId != _boundCaseId) {
      _boundCaseId = caseId;
      _threadsReady =
          caseId != null ? CaseMessagingService.ensureCaseThreads(caseId) : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId;
    final coparentId = context.watch<CaseContext>().coparentId;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: Text(context.tTone('messages')),
        elevation: 0,
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
      ),
      body: caseId == null || uid == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No case linked yet. Complete workspace setup to use case messages.',
                  textAlign: TextAlign.center,
                  style: PLDesign.body.copyWith(height: 1.4),
                ),
              ),
            )
          : FutureBuilder<void>(
              future: _threadsReady,
              builder: (context, ensureSnap) {
                if (ensureSnap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Could not prepare threads: ${ensureSnap.error}',
                            textAlign: TextAlign.center,
                            style: PLDesign.body.copyWith(color: PLDesign.danger),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(() {
                              _threadsReady =
                                  CaseMessagingService.ensureCaseThreads(caseId);
                            }),
                            child: Text(context.tTone('retry')),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (ensureSnap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('cases')
                      .doc(caseId)
                      .snapshots(),
                  builder: (context, caseSnap) {
                    final caseData = caseSnap.data?.data();
                    final caseLabel = (caseData?['name'] ??
                            caseData?['caseName'] ??
                            'Case')
                        .toString();

                    Widget participantAndList(String coparentName) {
                      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream:
                            CaseParticipantService.watchParticipant(caseId, uid),
                        builder: (context, partSnap) {
                          final participantData = partSnap.data?.data();

                          return StreamBuilder<
                              List<
                                  QueryDocumentSnapshot<
                                      Map<String, dynamic>>>>(
                            stream: CaseMessagingService.watchConversationsSorted(
                                caseId),
                            builder: (context, convSnap) {
                              if (convSnap.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'Could not load conversations: ${convSnap.error}',
                                      style: PLDesign.body.copyWith(
                                        color: PLDesign.danger,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }
                              if (convSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !convSnap.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final raw = convSnap.data ?? [];
                              final docs =
                                  CaseThreadCatalog.sortInboxThreads(raw);
                              if (docs.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'No threads found.',
                                          style: PLDesign.sectionTitle,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton(
                                          onPressed: () => setState(() {
                                            _threadsReady =
                                                CaseMessagingService
                                                    .ensureCaseThreads(caseId);
                                          }),
                                          child: Text(context.tTone('setUpThreads')),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding:
                                    const EdgeInsets.only(top: 8, bottom: 24),
                                itemCount: docs.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  indent: 78,
                                  color:
                                      PLDesign.border.withValues(alpha: 0.6),
                                ),
                                itemBuilder: (context, i) {
                                  final doc = docs[i];
                                  final d = doc.data();
                                  final conversationId = doc.id;
                                  final preview =
                                      (d['lastMessagePreview'] ?? '').toString();
                                  final updated = d['updatedAt'];
                                  Timestamp? ts;
                                  if (updated is Timestamp) ts = updated;

                                  final caseWide = (participantData?[
                                              'unreadMessageCount'] as num?)
                                          ?.toInt() ??
                                      0;
                                  final unread =
                                      CaseParticipantService
                                          .unreadForConversation(
                                    participantData,
                                    conversationId,
                                    caseWideFallback: caseWide,
                                    conversationListLength: docs.length,
                                  );
                                  final hasUnread = unread > 0;

                                  final title = MessagesInboxScreen._rowTitle(
                                    conversationId: conversationId,
                                    conv: d,
                                    caseLabel: caseLabel,
                                    coparentName: coparentName,
                                  );

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => MessagesInboxScreen.openThread(
                                        context,
                                        caseId: caseId,
                                        conversationId: conversationId,
                                        title: title,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 26,
                                              backgroundColor: PLDesign.primary
                                                  .withValues(alpha: 0.18),
                                              child: Text(
                                                title.isNotEmpty
                                                    ? title[0].toUpperCase()
                                                    : '?',
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: hasUnread
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  color: PLDesign.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: PLDesign.body
                                                        .copyWith(
                                                      fontSize: 17,
                                                      fontWeight: hasUnread
                                                          ? FontWeight.w700
                                                          : FontWeight.w600,
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    preview.isEmpty
                                                        ? 'No messages yet — conversations here are securely recorded'
                                                        : preview,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: PLDesign.caption
                                                        .copyWith(
                                                      fontSize: 15,
                                                      height: 1.25,
                                                      color: hasUnread
                                                          ? PLDesign.textMuted
                                                              .withValues(
                                                                  alpha: 0.95)
                                                          : PLDesign.textMuted,
                                                      fontWeight: hasUnread
                                                          ? FontWeight.w500
                                                          : FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  MessagesInboxScreen
                                                      ._formatListTime(ts),
                                                  style: PLDesign.caption
                                                      .copyWith(
                                                    fontSize: 13,
                                                    color: hasUnread
                                                        ? PLDesign.primary
                                                        : PLDesign.textMuted,
                                                    fontWeight: hasUnread
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                  ),
                                                ),
                                                if (hasUnread) ...[
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 7,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: PLDesign.primary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Text(
                                                      unread > 99
                                                          ? '99+'
                                                          : '$unread',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    }

                    if (coparentId == null) {
                      return participantAndList('');
                    }
                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(coparentId)
                          .snapshots(),
                      builder: (context, userSnap) {
                        final coparentName =
                            MessagesInboxScreen._displayNameFromUserDoc(
                                userSnap.data?.data());
                        return participantAndList(coparentName);
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
