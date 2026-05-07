import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../services/attorney_case_priority.dart';
import '../../services/attorney_client_card_loader.dart';
import '../../services/case_switcher_service.dart';
import '../../services/notification_service.dart';
import '../documents_library_screen.dart';
import '../enter_invite_code_screen.dart';
import '../legal_export_center_screen.dart';
import '../notifications_center_screen.dart';
import 'attorney_priority_badge.dart';
import 'client_case_screen.dart';

Future<void> _openCounselQuickActionsSheet(
  BuildContext context,
  List<AttorneyClientCardVm> models,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xff1a2438),
              PLDesign.bgBottom.withValues(alpha: 0.98),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Quick actions',
                  style: PLDesign.sectionTitle.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage documents, clients, and exports',
                  style: PLDesign.body.copyWith(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _FabSheetTile(
                  icon: Icons.upload_file_rounded,
                  title: 'Upload document',
                  subtitle: 'Add files to a client matter',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickCaseForDocumentsCounsel(context, models);
                  },
                ),
                const SizedBox(height: 10),
                _FabSheetTile(
                  icon: Icons.person_add_rounded,
                  title: 'Add client',
                  subtitle: 'Join a case with an invite code',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const EnterInviteCodeScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _FabSheetTile(
                  icon: Icons.description_outlined,
                  title: 'Export report',
                  subtitle: 'Court-ready bundle for selected matter',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _openExportCenterCounsel(context, models);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _pickCaseForDocumentsCounsel(
  BuildContext context,
  List<AttorneyClientCardVm> models,
) {
  if (models.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add a client matter first.')),
    );
    return;
  }
  if (models.length == 1) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            DocumentsLibraryScreen(caseId: models.first.caseId),
      ),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: PLDesign.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Choose matter',
              style: PLDesign.sectionTitle.copyWith(fontSize: 16),
            ),
          ),
          ...models.map(
            (vm) => ListTile(
              title: Text(vm.parentNamesLabel),
              subtitle: Text(vm.caseStatusLabel),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DocumentsLibraryScreen(caseId: vm.caseId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openExportCenterCounsel(
  BuildContext context,
  List<AttorneyClientCardVm> models,
) async {
  if (models.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add a client matter first.')),
    );
    return;
  }
  final switcher = context.read<CaseSwitcherService>();
  final selected = switcher.selectedCaseId;
  if (selected == null ||
      selected.isEmpty ||
      !models.any((e) => e.caseId == selected)) {
    await switcher.selectCase(models.first.caseId);
  }
  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => const LegalExportCenterScreen(),
    ),
  );
}

/// Attorney landing screen: all matters linked under `users/{uid}/cases`.
class AttorneyDashboardScreen extends StatefulWidget {
  const AttorneyDashboardScreen({super.key});

  @override
  State<AttorneyDashboardScreen> createState() => _AttorneyDashboardScreenState();
}

class _AttorneyDashboardScreenState extends State<AttorneyDashboardScreen> {
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      floatingActionButton: null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xff152238),
              Color(0xff0c1220),
              Color(0xff080d18),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('cases')
              .orderBy('linkedAt', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load matters. Check your connection and try again.',
                    style: PLDesign.body.copyWith(height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final rows = snap.data?.docs ?? [];
            if (rows.isEmpty) {
              return _AttorneyEmptyState(
                uid: uid,
                introDone: _introDone,
                onIntroComplete: () {
                  if (mounted) setState(() => _introDone = true);
                },
              );
            }
            return _AttorneyDashboardLoaded(
              uid: uid,
              rows: rows,
              introDone: _introDone,
              onIntroComplete: () {
                if (mounted) setState(() => _introDone = true);
              },
            );
          },
        ),
      ),
    );
  }
}

class _AttorneyEmptyState extends StatefulWidget {
  const _AttorneyEmptyState({
    required this.uid,
    required this.introDone,
    required this.onIntroComplete,
  });

  final String uid;
  final bool introDone;
  final VoidCallback onIntroComplete;

  @override
  State<_AttorneyEmptyState> createState() => _AttorneyEmptyStateState();
}

class _AttorneyEmptyStateState extends State<_AttorneyEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    if (!widget.introDone) {
      _c.forward().then((_) {
        if (mounted) widget.onIntroComplete();
      });
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Opacity(
              opacity: _fade.value,
              child: Transform.scale(scale: _scale.value, child: child),
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _DashboardHeader(uid: widget.uid),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No clients yet',
                          style: PLDesign.sectionTitle.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'When a parent invites you or your firm links a matter, '
                          'it will appear here. Join with an invite code to get started.',
                          style: PLDesign.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.62),
                            height: 1.5,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        _PrimaryCtaButton(
                          label: 'Enter invite code',
                          icon: Icons.vpn_key_rounded,
                          onTap: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const EnterInviteCodeScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: _DashboardFab(
              onOpenMenu: (ctx) =>
                  _openCounselQuickActionsSheet(context, const []),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttorneyDashboardLoaded extends StatefulWidget {
  const _AttorneyDashboardLoaded({
    required this.uid,
    required this.rows,
    required this.introDone,
    required this.onIntroComplete,
  });

  final String uid;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> rows;
  final bool introDone;
  final VoidCallback onIntroComplete;

  @override
  State<_AttorneyDashboardLoaded> createState() => _AttorneyDashboardLoadedState();
}

class _AttorneyDashboardLoadedState extends State<_AttorneyDashboardLoaded> {
  Timer? _timer;
  int _pulse = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) setState(() => _pulse++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowKey = widget.rows.map((e) => e.id).join(',');
    return FutureBuilder<List<AttorneyClientCardVm>>(
      key: ValueKey('${rowKey}_$_pulse'),
      future: AttorneyClientCardLoader.loadAll(widget.rows),
      builder: (context, modelSnap) {
        final models = modelSnap.data;
        if (models == null) {
          return const Center(
            child: CircularProgressIndicator(color: PLDesign.primary),
          );
        }
        return _DashboardScrollBody(
          uid: widget.uid,
          models: models,
          introDone: widget.introDone,
          onIntroComplete: widget.onIntroComplete,
        );
      },
    );
  }
}

class _DashboardScrollBody extends StatefulWidget {
  const _DashboardScrollBody({
    required this.uid,
    required this.models,
    required this.introDone,
    required this.onIntroComplete,
  });

  final String uid;
  final List<AttorneyClientCardVm> models;
  final bool introDone;
  final VoidCallback onIntroComplete;

  @override
  State<_DashboardScrollBody> createState() => _DashboardScrollBodyState();
}

class _DashboardScrollBodyState extends State<_DashboardScrollBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.98, end: 1).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    if (!widget.introDone) {
      _c.forward().then((_) {
        if (mounted) widget.onIntroComplete();
      });
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.models;
    final activeCount = m.where((e) => e.isActive).length;
    final openCases = m.length;
    final recentCutoff = DateTime.now().subtract(const Duration(hours: 48));
    final recentActivity = m
        .where((e) =>
            e.lastActivityDisplay != null &&
            e.lastActivityDisplay!.isAfter(recentCutoff))
        .length;

    final needsAttention = m
        .where((e) =>
            e.status.priority != AttorneyCasePriority.stable ||
            e.status.needsAttention)
        .toList();

    final avgHealth = m.isEmpty
        ? 0.0
        : m.map((e) => e.status.healthScore).reduce((a, b) => a + b) /
            m.length;
    final totalMissed =
        m.fold<int>(0, (s, e) => s + e.status.missedExchangeCount);
    final totalFlags =
        m.fold<int>(0, (s, e) => s + e.status.flaggedMessageCount);

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(scale: _scale.value, child: child),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 108),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DashboardHeader(uid: widget.uid),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _QuickStatsRow(
                    activeClients: activeCount,
                    openCases: openCases,
                    recentActivity: recentActivity,
                  ),
                ),
                if (needsAttention.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _NeedsAttentionSection(
                      clients: needsAttention,
                      timeAgo: _lastActivityLabel,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'Your Clients',
                    style: PLDesign.sectionTitle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...m.map(
                  (vm) => Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: _GlassClientCard(
                      vm: vm,
                      lastActivity: _lastActivityLabel(vm.lastActivityDisplay),
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ClientCaseScreen(
                              clientId: vm.caseId,
                              clientName: vm.parentNamesLabel,
                              caseStatusLabel: vm.caseStatusLabel,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _InsightsSnapshotSection(
                    healthScore: avgHealth,
                    missedExchanges: totalMissed,
                    messageFlags: totalFlags,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: _DashboardFab(
            onOpenMenu: (ctx) => _openCounselQuickActionsSheet(context, m),
          ),
        ),
      ],
    );
  }

  static String _lastActivityLabel(DateTime? t) {
    if (t == null) return 'No recent activity';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Updated just now';
    if (d.inHours < 1) return 'Updated ${d.inMinutes}m ago';
    if (d.inDays < 1) return 'Updated ${d.inHours}h ago';
    if (d.inDays < 7) return 'Updated ${d.inDays}d ago';
    return 'Updated ${DateFormat.yMMMd().format(t.toLocal())}';
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final initial = (user?.displayName?.trim().isNotEmpty == true)
        ? user!.displayName!.trim()[0].toUpperCase()
        : (user?.email != null && user!.email!.isNotEmpty)
            ? user.email![0].toUpperCase()
            : '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attorney Dashboard',
                  style: PLDesign.heroTitle.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage your client cases',
                  style: PLDesign.body.copyWith(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.58),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsCenterScreen(),
                ),
              );
            },
            icon: StreamBuilder<int>(
              stream: NotificationService.watchCounselFilteredUnreadCount(uid),
              builder: (context, snap) {
                final unread = snap.data ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: PLDesign.danger,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  PLDesign.primary.withValues(alpha: 0.85),
                  PLDesign.primary.withValues(alpha: 0.45),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: PLDesign.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.activeClients,
    required this.openCases,
    required this.recentActivity,
  });

  final int activeClients;
  final int openCases;
  final int recentActivity;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _StatCard(
            value: '$activeClients',
            label: 'Active Clients',
          ),
          const SizedBox(width: 12),
          _StatCard(
            value: '$openCases',
            label: 'Open Cases',
          ),
          const SizedBox(width: 12),
          _StatCard(
            value: '$recentActivity',
            label: 'Recent Activity',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff1c2a44),
            Color(0xff121c30),
          ],
        ),
        border: Border.all(
          color: PLDesign.primary.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: PLDesign.primary.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: PLDesign.statNumber.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: PLDesign.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedsAttentionSection extends StatelessWidget {
  const _NeedsAttentionSection({
    required this.clients,
    required this.timeAgo,
  });

  final List<AttorneyClientCardVm> clients;
  final String Function(DateTime?) timeAgo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.priority_high_rounded,
              color: PLDesign.warning,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Needs Attention',
              style: PLDesign.sectionTitle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...clients.take(6).map(
              (vm) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ClientCaseScreen(
                            clientId: vm.caseId,
                            clientName: vm.parentNamesLabel,
                            caseStatusLabel: vm.caseStatusLabel,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            PLDesign.danger.withValues(alpha: 0.14),
                            PLDesign.warning.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(
                          color: PLDesign.warning.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PLDesign.warning.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: PLDesign.warning,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vm.parentNamesLabel,
                                    style: PLDesign.sectionTitle.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    vm.status.keyStatSummary,
                                    style: PLDesign.body.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.78,
                                      ),
                                      fontSize: 14,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    timeAgo(vm.lastActivityDisplay),
                                    style: PLDesign.caption.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.45,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _GlassClientCard extends StatelessWidget {
  const _GlassClientCard({
    required this.vm,
    required this.lastActivity,
    required this.onTap,
  });

  final AttorneyClientCardVm vm;
  final String lastActivity;
  final VoidCallback onTap;

  Color _statusColor(String label) {
    switch (label) {
      case 'Active':
        return PLDesign.success;
      case 'Pending':
        return PLDesign.warning;
      case 'Closed':
        return PLDesign.textMuted;
      default:
        return PLDesign.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(vm.caseStatusLabel);
    final clean = vm.status.priority == AttorneyCasePriority.stable &&
        !vm.status.needsAttention;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withValues(alpha: 0.07),
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            vm.parentNamesLabel,
                            style: PLDesign.sectionTitle.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            vm.caseStatusLabel,
                            style: PLDesign.caption.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        AttorneyPriorityBadge(
                          priority: vm.status.priority,
                          compact: true,
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          clean
                              ? Icons.verified_outlined
                              : Icons.flag_outlined,
                          size: 17,
                          color: clean
                              ? PLDesign.success.withValues(alpha: 0.85)
                              : PLDesign.warning.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            lastActivity,
                            style: PLDesign.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.52),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      vm.status.keyStatSummary,
                      style: PLDesign.body.copyWith(
                        fontSize: 14,
                        height: 1.35,
                        color: vm.status.needsAttention
                            ? PLDesign.warning.withValues(alpha: 0.95)
                            : Colors.white.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Open case',
                        style: PLDesign.caption.copyWith(
                          color: PLDesign.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightsSnapshotSection extends StatelessWidget {
  const _InsightsSnapshotSection({
    required this.healthScore,
    required this.missedExchanges,
    required this.messageFlags,
  });

  final double healthScore;
  final int missedExchanges;
  final int messageFlags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Case Insights',
          style: PLDesign.sectionTitle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _InsightTile(
                icon: Icons.favorite_outline_rounded,
                label: 'Health',
                value: healthScore.isFinite
                    ? '${healthScore.round()}'
                    : '—',
                accent: PLDesign.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                icon: Icons.swap_horiz_rounded,
                label: 'Missed exchanges',
                value: '$missedExchanges',
                accent: missedExchanges > 0 ? PLDesign.warning : PLDesign.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                icon: Icons.outlined_flag_rounded,
                label: 'Msg flags',
                value: '$messageFlags',
                accent: messageFlags > 0 ? PLDesign.warning : PLDesign.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: PLDesign.card.withValues(alpha: 0.65),
        border: Border.all(
          color: accent.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Text(
            value,
            style: PLDesign.statNumber.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: PLDesign.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DashboardFab extends StatelessWidget {
  const _DashboardFab({
    required this.onOpenMenu,
  });

  final void Function(BuildContext context) onOpenMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: PLDesign.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: PLDesign.primary.withValues(alpha: 0.45),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onOpenMenu(context),
          child: const SizedBox(
            width: 58,
            height: 58,
            child: Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _FabSheetTile extends StatelessWidget {
  const _FabSheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PLDesign.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: PLDesign.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PLDesign.sectionTitle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: PLDesign.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryCtaButton extends StatelessWidget {
  const _PrimaryCtaButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: PLDesign.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: PLDesign.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: PLDesign.buttonText.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
