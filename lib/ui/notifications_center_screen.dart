import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../design/design.dart';
import '../providers/case_context.dart';
import '../services/attorney_notification_preferences.dart';
import '../services/case_switcher_service.dart';
import '../services/notification_service.dart';
import 'attorney/client_case_screen.dart';
import 'case_unified_timeline_screen.dart';
import 'expenses_list_screen.dart';
import 'messages_inbox_screen.dart';

class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  Map<String, bool>? _counselFilters;

  @override
  void initState() {
    super.initState();
    _loadCounselFilters();
  }

  Future<void> _loadCounselFilters() async {
    final m = await AttorneyNotificationPreferences.loadAll();
    if (mounted) setState(() => _counselFilters = m);
  }

  Future<void> _setCounselFilter(String cat, bool enabled) async {
    await AttorneyNotificationPreferences.setCategoryEnabled(cat, enabled);
    final next = Map<String, bool>.from(_counselFilters ?? {});
    next[cat] = enabled;
    if (mounted) setState(() => _counselFilters = next);
  }

  Color _accentForType(String type) {
    switch (type) {
      case 'message':
        return Colors.blueAccent;
      case 'expense':
        return Colors.greenAccent;
      case 'alert':
        return Colors.redAccent;
      case 'system':
      default:
        return Colors.amberAccent;
    }
  }

  Color _accentForNotification(Map<String, dynamic> n) {
    final cc = (n['counselCategory'] ?? '').toString();
    switch (cc) {
      case 'exchange':
        return PLDesign.warning;
      case 'flagged_message':
        return PLDesign.danger;
      case 'document':
        return PLDesign.info;
      case 'activity':
        return PLDesign.ai;
      default:
        return _accentForType((n['type'] ?? 'system').toString());
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_outline_rounded;
      case 'expense':
        return Icons.receipt_long_rounded;
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'system':
      default:
        return Icons.notifications_none_rounded;
    }
  }

  IconData _iconForNotification(Map<String, dynamic> n) {
    final cc = (n['counselCategory'] ?? '').toString();
    switch (cc) {
      case 'exchange':
        return Icons.swap_horiz_rounded;
      case 'flagged_message':
        return Icons.flag_outlined;
      case 'document':
        return Icons.folder_open_outlined;
      case 'activity':
        return Icons.insights_outlined;
      default:
        return _iconForType((n['type'] ?? 'system').toString());
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return 'Now';
    final dt = ts.toDate();
    final now = DateTime.now();
    final delta = now.difference(dt);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  bool _passesCounselFilter(
    Map<String, dynamic> n,
    Map<String, bool> prefs,
  ) {
    final cc = (n['counselCategory'] ?? '').toString();
    if (cc.isEmpty) return true;
    return prefs[cc] ?? true;
  }

  String _chipLabel(String cat) {
    switch (cat) {
      case 'exchange':
        return 'Exchanges';
      case 'flagged_message':
        return 'Flagged';
      case 'document':
        return 'Documents';
      case 'activity':
        return 'Activity';
      default:
        return cat;
    }
  }

  Future<void> _openNotification(
    BuildContext context,
    String userId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final type = (data['type'] ?? 'system').toString();
    final caseId = (data['caseId'] ?? '').toString();
    final counselCat = (data['counselCategory'] ?? '').toString();
    final session = context.read<CaseContext>();
    final switchedCaseId = context.read<CaseSwitcherService>().selectedCaseId;
    final activeCaseId = session.isAttorney
        ? (switchedCaseId ?? session.caseId ?? caseId)
        : (session.caseId ?? caseId);
    final targetCaseId = caseId.isNotEmpty ? caseId : activeCaseId;

    if (data['read'] != true) {
      await NotificationService.markRead(
        userId: userId,
        notificationId: doc.id,
      );
    }
    if (!context.mounted) return;

    Widget? next;
    if (session.isAttorney &&
        counselCat.isNotEmpty &&
        caseId.isNotEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ClientCaseScreen(clientId: caseId),
        ),
      );
      return;
    }

    switch (type) {
      case 'message':
        next = const MessagesInboxScreen();
        break;
      case 'expense':
        next = const ExpensesListScreen();
        break;
      case 'alert':
      case 'system':
      default:
        if (targetCaseId.isNotEmpty) {
          next = CaseUnifiedTimelineScreen(caseId: targetCaseId);
        }
    }
    if (next != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => next!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: PLDesign.background,
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Sign in to view notifications.')),
      );
    }

    final session = context.watch<CaseContext>();
    final isAttorney = session.isAttorney;
    final prefs = _counselFilters;

    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationService.markAllAsRead(uid);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications marked as read'),
                ),
              );
            },
            child: const Text('Mark all as read'),
          ),
        ],
      ),
      body: Container(
        decoration: PLDesign.screenGradient,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: NotificationService.watchUserNotifications(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? const [];
            if (docs.isEmpty) {
              return Center(
                child: Text(
                  "You're all caught up",
                  style: PLDesign.sectionTitle,
                ),
              );
            }

            List<QueryDocumentSnapshot<Map<String, dynamic>>> visible =
                docs;
            if (isAttorney && prefs != null) {
              visible = docs
                  .where((d) => _passesCounselFilter(d.data(), prefs))
                  .toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isAttorney && prefs != null) ...[
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Text(
                      'Show types',
                      style: PLDesign.caption.copyWith(
                        color: PLDesign.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: AttorneyNotificationPreferences.allCategories
                          .map(
                            (cat) => FilterChip(
                              label: Text(_chipLabel(cat)),
                              selected: prefs[cat] ?? true,
                              onSelected: (v) => _setCounselFilter(cat, v),
                              selectedColor:
                                  PLDesign.primary.withValues(alpha: 0.22),
                              checkmarkColor: PLDesign.primary,
                              labelStyle: PLDesign.caption,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              isAttorney
                                  ? 'No notifications match these filters.'
                                  : "You're all caught up",
                              style: PLDesign.sectionTitle,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final doc = visible[index];
                            final n = doc.data();
                            final title =
                                (n['title'] ?? 'Notification').toString();
                            final body = (n['body'] ?? '').toString();
                            final read = n['read'] == true;
                            final createdAt = n['createdAt'];
                            final accent = _accentForNotification(n);
                            final icon = _iconForNotification(n);
                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () =>
                                  _openNotification(context, uid, doc),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: PLDesign.card.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: read
                                        ? PLDesign.border
                                            .withValues(alpha: 0.7)
                                        : accent.withValues(alpha: 0.55),
                                  ),
                                  boxShadow: PLDesign.softShadow,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color:
                                            accent.withValues(alpha: 0.18),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(icon, color: accent),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: PLDesign.body
                                                      .copyWith(
                                                    fontWeight: read
                                                        ? FontWeight.w600
                                                        : FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _formatTime(
                                                  createdAt is Timestamp
                                                      ? createdAt
                                                      : null,
                                                ),
                                                style: PLDesign.caption,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            body,
                                            style: PLDesign.caption.copyWith(
                                              color: PLDesign.textMuted,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!read)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          left: 8,
                                          top: 6,
                                        ),
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
