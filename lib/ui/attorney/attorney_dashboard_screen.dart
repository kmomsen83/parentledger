import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/design.dart';
import '../../services/attorney_case_priority.dart';
import '../../services/attorney_client_card_loader.dart';
import '../../services/notification_service.dart';
import '../enter_invite_code_screen.dart';
import '../notifications_center_screen.dart';
import 'attorney_priority_badge.dart';
import 'attorney_profile_screen.dart';
import 'client_workspace_screen.dart';

List<Widget> _pendingInviteSlivers(List<AttorneyClientCardVm> models) {
  final pending =
      models.where((m) => m.caseStatusLabel == 'Pending').toList();
  if (pending.isEmpty) return <Widget>[];
  return <Widget>[
    const SliverToBoxAdapter(child: _SectionLabel('PENDING INVITES')),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _PremiumClientCard(
          vm: pending[i],
          onTap: () => _openClientWorkspace(context, pending[i]),
        ),
      ),
    ),
    const SliverToBoxAdapter(child: SizedBox(height: 18)),
  ];
}

List<Widget> _activeClientWorkspaceSlivers(List<AttorneyClientCardVm> models) {
  final active =
      models.where((m) => m.caseStatusLabel != 'Pending').toList();
  if (active.isEmpty) {
    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            models.any((m) => m.caseStatusLabel == 'Pending')
                ? 'Active matters appear here when invites are accepted.'
                : 'Link a client to open a dedicated workspace.',
            style: PLDesign.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
              height: 1.35,
            ),
          ),
        ),
      ),
    ];
  }
  return <Widget>[
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: active.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _PremiumClientCard(
          vm: active[i],
          onTap: () => _openClientWorkspace(context, active[i]),
        ),
      ),
    ),
  ];
}

void _openClientWorkspace(BuildContext context, AttorneyClientCardVm vm) {
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ClientWorkspaceScreen(
        caseId: vm.caseId,
        parentNamesLabel: vm.parentNamesLabel,
        caseStatusLabel: vm.caseStatusLabel,
      ),
    ),
  );
}

/// Premium attorney command center: matters, summary tiles, activity, exports.
///
/// All counsel-facing data is read from `users/{uid}/cases/*` link rows and
/// hydrated through [AttorneyClientCardLoader]. The screen renders the same
/// information density whether the attorney has zero or many linked matters.
class AttorneyDashboardScreen extends StatefulWidget {
  const AttorneyDashboardScreen({super.key});

  @override
  State<AttorneyDashboardScreen> createState() =>
      _AttorneyDashboardScreenState();
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
              return _ErrorBody(message: '${snap.error}');
            }
            final rows = snap.data?.docs ?? [];
            return _AttorneyDashboardBody(
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

// -----------------------------------------------------------------------------
// Body
// -----------------------------------------------------------------------------

class _AttorneyDashboardBody extends StatefulWidget {
  const _AttorneyDashboardBody({
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
  State<_AttorneyDashboardBody> createState() => _AttorneyDashboardBodyState();
}

class _AttorneyDashboardBodyState extends State<_AttorneyDashboardBody> {
  Timer? _pulseTimer;
  int _pulse = 0;

  @override
  void initState() {
    super.initState();
    _pulseTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() => _pulse++);
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowKey = widget.rows.map((e) => e.id).join(',');

    return FutureBuilder<List<AttorneyClientCardVm>>(
      key: ValueKey('${rowKey}_$_pulse'),
      future: AttorneyClientCardLoader.loadAll(widget.rows, widget.uid),
      builder: (context, modelSnap) {
        final models = modelSnap.data;
        return SafeArea(
          child: RefreshIndicator(
            color: PLDesign.primary,
            backgroundColor: PLDesign.surface,
            onRefresh: () async {
              setState(() => _pulse++);
              await Future<void>.delayed(const Duration(milliseconds: 350));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _AttorneyDashboardHeader(uid: widget.uid),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 6)),
                const SliverToBoxAdapter(child: _TrustRibbon()),
                const SliverToBoxAdapter(child: SizedBox(height: 18)),
                if (models == null) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 32, 16, 80),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: PLDesign.primary,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  if (models.isEmpty) ...[
                    const SliverToBoxAdapter(child: _EmptyWorkspaceCard()),
                    const SliverToBoxAdapter(child: SizedBox(height: 22)),
                    const SliverToBoxAdapter(
                      child: _SectionLabel('GETTING STARTED'),
                    ),
                    SliverToBoxAdapter(
                      child: _OnboardingChecklist(models: models),
                    ),
                  ] else ...[
                    ..._pendingInviteSlivers(models),
                    SliverToBoxAdapter(
                      child: _SectionLabel(
                        'CLIENT WORKSPACES',
                        trailing: Text(
                          '${models.length} linked',
                          style: PLDesign.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    ..._activeClientWorkspaceSlivers(models),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 22)),
                  SliverToBoxAdapter(
                    child: _SectionLabel(
                      'QUICK ACTIONS',
                      trailing: _PermissionsHint(),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: _DashboardQuickActionsRow(),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  const SliverToBoxAdapter(
                    child: _SectionLabel('RECENT ACTIVITY'),
                  ),
                  SliverToBoxAdapter(
                    child: _RecentActivityList(models: models),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Header
// -----------------------------------------------------------------------------

class _AttorneyDashboardHeader extends StatelessWidget {
  const _AttorneyDashboardHeader({required this.uid});

  final String uid;

  static String _initials(String fullName, String? email) {
    final t = fullName.trim();
    if (t.isNotEmpty) {
      final parts =
          t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return t[0].toUpperCase();
    }
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return 'A';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() ?? {};
        final fn = (d['firstName'] ?? '').toString().trim();
        final ln = (d['lastName'] ?? '').toString().trim();
        final firm = (d['firmName'] ?? '').toString().trim();
        final fullName = '$fn $ln'.trim();
        final user = FirebaseAuth.instance.currentUser;
        final photo = (d['profilePhotoUrl'] ?? '').toString().trim();
        final fbPhoto = (user?.photoURL ?? '').toString().trim();
        final email =
            (d['email'] ?? user?.email ?? '').toString().trim();
        final usePhoto = photo.isNotEmpty ? photo : fbPhoto;
        final displayTitle = fullName.isNotEmpty
            ? fullName
            : (user?.displayName ?? 'Counsel').trim();
        final initials =
            _initials(displayTitle, email.isNotEmpty ? email : user?.email);

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AttorneyProfileScreen(),
                    ),
                  ),
                  child: _CounselAvatar(photoUrl: usePhoto, initials: initials),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            displayTitle.isEmpty ? 'Counsel' : displayTitle,
                            style: PLDesign.heroTitle.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: PLDesign.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: PLDesign.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'ATTORNEY',
                            style: PLDesign.caption.copyWith(
                              color: PLDesign.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (firm.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        firm,
                        style: PLDesign.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.66),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Command center · client overview',
                      style: PLDesign.dashboardSectionLabel.copyWith(
                        color: PLDesign.premiumGold.withValues(alpha: 0.82),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              _CircleIconButton(
                tooltip: 'Search matters',
                icon: Icons.search_rounded,
                onTap: () => _openSearchSheet(context, uid),
              ),
              const SizedBox(width: 8),
              _NotificationsBell(uid: uid),
            ],
          ),
        );
      },
    );
  }
}

class _CounselAvatar extends StatelessWidget {
  const _CounselAvatar({
    required this.photoUrl,
    required this.initials,
  });

  final String photoUrl;
  final String initials;

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final Widget inner = photoUrl.isNotEmpty
        ? ClipOval(
            child: Image.network(
              photoUrl,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialsBackdrop(),
            ),
          )
        : _initialsBackdrop();

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: PLDesign.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }

  Widget _initialsBackdrop() {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PLDesign.primary.withValues(alpha: 0.92),
            PLDesign.ai.withValues(alpha: 0.82),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.length > 2 ? initials.substring(0, 2) : initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
    );
  }
}

class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return _CircleIconButton(
      tooltip: 'Notifications',
      onTap: () {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const NotificationsCenterScreen(),
          ),
        );
      },
      child: StreamBuilder<int>(
        stream: NotificationService.watchCounselFilteredUnreadCount(uid),
        builder: (context, snap) {
          final unread = snap.data ?? 0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: Colors.white.withValues(alpha: 0.92),
                size: 20,
              ),
              if (unread > 0)
                Positioned(
                  right: -6,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: PLDesign.danger,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xff0c1220),
                        width: 1.4,
                      ),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.onTap,
    this.icon,
    this.child,
    this.tooltip,
  }) : assert(icon != null || child != null);

  final VoidCallback onTap;
  final IconData? icon;
  final Widget? child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      alignment: Alignment.center,
      child: child ??
          Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.92),
            size: 20,
          ),
    );
    final widget = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: btn,
      ),
    );
    if (tooltip == null) return widget;
    return Tooltip(message: tooltip!, child: widget);
  }
}

// -----------------------------------------------------------------------------
// Trust ribbon
// -----------------------------------------------------------------------------

class _TrustRibbon extends StatelessWidget {
  const _TrustRibbon();

  @override
  Widget build(BuildContext context) {
    const items = <_TrustItem>[
      _TrustItem(Icons.gavel_rounded, 'Court-ready'),
      _TrustItem(Icons.lock_outline_rounded, 'Secure vault'),
      _TrustItem(Icons.history_rounded, 'Synced timeline'),
      _TrustItem(Icons.verified_user_outlined, 'Verified records'),
      _TrustItem(Icons.visibility_outlined, 'Read-only access'),
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: PLDesign.premiumGold.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: 13,
                  color: PLDesign.premiumChampagne.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: PLDesign.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrustItem {
  const _TrustItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

// -----------------------------------------------------------------------------
// Section label
// -----------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: PLDesign.premiumGold.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: PLDesign.dashboardSectionLabel.copyWith(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 10.5,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Dashboard quick actions (global — matter tools live in each workspace)
// -----------------------------------------------------------------------------

class _DashboardQuickActionsRow extends StatelessWidget {
  const _DashboardQuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          _DashQuickChip(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Add client',
            subtitle: 'Invite code',
            accent: PLDesign.primary,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const EnterInviteCodeScreen(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _DashQuickChip(
            icon: Icons.notifications_active_outlined,
            label: 'Notifications',
            subtitle: 'Counsel alerts',
            accent: PLDesign.info,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsCenterScreen(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _DashQuickChip(
            icon: Icons.badge_outlined,
            label: 'Attorney profile',
            subtitle: 'Branding & account',
            accent: PLDesign.premiumGold,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AttorneyProfileScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashQuickChip extends StatelessWidget {
  const _DashQuickChip({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.42)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: PLDesign.sectionTitle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: PLDesign.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionsHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 13,
          color: PLDesign.success.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 4),
        Text(
          'Read-only',
          style: PLDesign.caption.copyWith(
            color: PLDesign.success.withValues(alpha: 0.92),
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Empty state — premium "workspace ready" card
// -----------------------------------------------------------------------------

class _EmptyWorkspaceCard extends StatelessWidget {
  const _EmptyWorkspaceCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: PLDesign.premiumCaseCardGradient,
              border: Border.all(
                color: PLDesign.premiumGold.withValues(alpha: 0.32),
              ),
              boxShadow: [
                const BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
                BoxShadow(
                  color: PLDesign.premiumGold.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LegalPatternPainter(
                      color: PLDesign.premiumGold.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  PLDesign.premiumGold.withValues(alpha: 0.22),
                                  PLDesign.premiumGold.withValues(alpha: 0.04),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: PLDesign.premiumGold
                                    .withValues(alpha: 0.32),
                              ),
                            ),
                            child: const Icon(
                              Icons.account_balance_outlined,
                              color: PLDesign.premiumChampagne,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'CLIENT HUB',
                            style: PLDesign.premiumCaseEyebrow,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Build your\nclient roster.',
                        style: PLDesign.premiumCaseTitle.copyWith(
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Each connected client opens a dedicated workspace '
                        'for timelines, messages, documents, exports, and '
                        'court-ready bundles.',
                        style: PLDesign.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.5,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _PrimaryGoldCta(
                              icon: Icons.vpn_key_rounded,
                              label: 'Connect first client',
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const EnterInviteCodeScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _LegalPatternPainter extends CustomPainter {
  _LegalPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const step = 24.0;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LegalPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PrimaryGoldCta extends StatelessWidget {
  const _PrimaryGoldCta({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xffd9b441),
                Color(0xffb88a1d),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: PLDesign.premiumGold.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xff1a1505), size: 18),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xff1a1505),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.2,
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

// -----------------------------------------------------------------------------
// Onboarding checklist (shown when no clients)
// -----------------------------------------------------------------------------

class _OnboardingChecklist extends StatelessWidget {
  const _OnboardingChecklist({required this.models});

  final List<AttorneyClientCardVm> models;

  @override
  Widget build(BuildContext context) {
    final hasAny = models.isNotEmpty;
    final hasRecent = models.any((e) =>
        e.lastActivityDisplay != null &&
        DateTime.now()
                .difference(e.lastActivityDisplay!)
                .inDays <
            14);

    final items = <_ChecklistItem>[
      _ChecklistItem(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Connect first client',
        subtitle: 'Use a 6-digit invite code',
        done: hasAny,
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const EnterInviteCodeScreen(),
          ),
        ),
      ),
      _ChecklistItem(
        icon: Icons.cloud_upload_outlined,
        title: 'Upload first document',
        subtitle: 'Open a client workspace → Documents',
        done: hasRecent,
        onTap: hasAny
            ? () => _openClientWorkspace(context, models.first)
            : null,
      ),
      _ChecklistItem(
        icon: Icons.history_rounded,
        title: 'Review case timeline',
        subtitle: 'Open a client workspace → Matter tools',
        done: hasRecent,
        onTap: hasAny
            ? () => _openClientWorkspace(context, models.first)
            : null,
      ),
      _ChecklistItem(
        icon: Icons.picture_as_pdf_outlined,
        title: 'Export first court bundle',
        subtitle: 'Open a client workspace → Exports',
        done: false,
        onTap: hasAny
            ? () => _openClientWorkspace(context, models.first)
            : null,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _ChecklistRow(item: items[i]),
              if (i != items.length - 1)
                Divider(
                  color: Colors.white.withValues(alpha: 0.05),
                  height: 14,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem {
  const _ChecklistItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onTap;
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item});

  final _ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final accent = item.done ? PLDesign.success : PLDesign.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
                border: Border.all(
                  color: accent.withValues(alpha: 0.45),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                item.done ? Icons.check_rounded : item.icon,
                color: accent,
                size: 15,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: PLDesign.sectionTitle.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: item.done
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.white,
                      decoration: item.done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor:
                          Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: PLDesign.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (item.onTap != null && !item.done)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.35),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Premium client card
// -----------------------------------------------------------------------------

class _PremiumClientCard extends StatelessWidget {
  const _PremiumClientCard({required this.vm, required this.onTap});

  final AttorneyClientCardVm vm;
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
    final priority = vm.status.priority;
    final accent = attorneyPriorityAccent(priority);
    final stColor = _statusColor(vm.caseStatusLabel);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withValues(alpha: 0.05),
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.09),
                    Colors.white.withValues(alpha: 0.025),
                  ],
                ),
                border: Border.all(
                  color: priority == AttorneyCasePriority.stable
                      ? Colors.white.withValues(alpha: 0.1)
                      : accent.withValues(alpha: 0.45),
                  width:
                      priority == AttorneyCasePriority.stable ? 1.0 : 1.4,
                ),
                boxShadow: priority == AttorneyCasePriority.stable
                    ? const []
                    : [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.16),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: 0.15),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.4),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.gavel_rounded,
                            size: 17,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vm.parentNamesLabel,
                                style: PLDesign.sectionTitle.copyWith(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                vm.caseTitle,
                                style: PLDesign.caption.copyWith(
                                  color:
                                      Colors.white.withValues(alpha: 0.62),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _lastActivityLabel(vm.lastActivityDisplay),
                                style: PLDesign.caption.copyWith(
                                  color:
                                      Colors.white.withValues(alpha: 0.45),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _StatusPill(
                              label: vm.caseStatusLabel,
                              color: stColor,
                            ),
                            const SizedBox(height: 6),
                            AttorneyPriorityBadge(
                              priority: priority,
                              compact: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ClientHubChip(
                          icon: vm.isActive
                              ? Icons.link_rounded
                              : Icons.hourglass_empty_rounded,
                          label: vm.isActive
                              ? 'Connected'
                              : 'Awaiting co-parent',
                          accent: vm.isActive
                              ? PLDesign.success
                              : PLDesign.warning,
                        ),
                        if (vm.unreadNotificationsCount > 0)
                          _ClientHubChip(
                            icon: Icons.mark_email_unread_outlined,
                            label:
                                '${vm.unreadNotificationsCount} unread',
                            accent: PLDesign.info,
                          ),
                        if (vm.status.flaggedMessageCount > 0 ||
                            vm.status.missedExchangeCount > 0)
                          _ClientHubChip(
                            icon: Icons.warning_amber_rounded,
                            label: 'Flagged activity',
                            accent: PLDesign.danger,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vm.status.needsAttention
                                ? vm.status.keyStatSummary
                                : 'Open workspace for timelines, messages, '
                                    'documents, and exports.',
                            style: PLDesign.body.copyWith(
                              color: vm.status.needsAttention
                                  ? accent.withValues(alpha: 0.95)
                                  : Colors.white.withValues(alpha: 0.58),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              colors: [
                                PLDesign.primary.withValues(alpha: 0.4),
                                PLDesign.ai.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Open',
                                style: PLDesign.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: PLDesign.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ClientHubChip extends StatelessWidget {
  const _ClientHubChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: PLDesign.caption.copyWith(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Recent activity (cross-matter top events)
// -----------------------------------------------------------------------------

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList({required this.models});

  final List<AttorneyClientCardVm> models;

  @override
  Widget build(BuildContext context) {
    final ranked = [...models]
      ..sort((a, b) {
        final aTs = a.lastActivityDisplay?.millisecondsSinceEpoch ?? 0;
        final bTs = b.lastActivityDisplay?.millisecondsSinceEpoch ?? 0;
        return bTs.compareTo(aTs);
      });

    final withActivity =
        ranked.where((e) => e.lastActivityDisplay != null).take(6).toList();

    if (withActivity.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.bolt_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Live activity will appear here as your clients log '
                  'exchanges, upload records, and update the case timeline.',
                  style: PLDesign.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Column(
          children: [
            for (var i = 0; i < withActivity.length; i++) ...[
              _ActivityRow(vm: withActivity[i]),
              if (i != withActivity.length - 1)
                Divider(
                  color: Colors.white.withValues(alpha: 0.05),
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.vm});

  final AttorneyClientCardVm vm;

  @override
  Widget build(BuildContext context) {
    final priority = vm.status.priority;
    final accent = attorneyPriorityAccent(priority);
    final headline = _activityHeadline(vm);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openClientWorkspace(context, vm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
                border: Border.all(
                  color: accent.withValues(alpha: 0.42),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                _activityIcon(vm),
                size: 15,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: PLDesign.sectionTitle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${vm.parentNamesLabel} · '
                    '${_lastActivityLabel(vm.lastActivityDisplay)}',
                    style: PLDesign.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.32),
            ),
          ],
        ),
      ),
    );
  }

  static String _activityHeadline(AttorneyClientCardVm vm) {
    if (vm.status.flaggedMessageCount > 0) return 'Flagged communication';
    if (vm.status.missedExchangeCount > 0) return 'Missed exchange logged';
    if (vm.status.unpaidExpenseCount > 0) return 'Reimbursement update';
    return 'Case timeline updated';
  }

  static IconData _activityIcon(AttorneyClientCardVm vm) {
    if (vm.status.flaggedMessageCount > 0) return Icons.flag_outlined;
    if (vm.status.missedExchangeCount > 0) return Icons.event_busy_outlined;
    if (vm.status.unpaidExpenseCount > 0) return Icons.payments_outlined;
    return Icons.history_rounded;
  }
}

// -----------------------------------------------------------------------------
// Bottom sheets
// -----------------------------------------------------------------------------

Future<void> _showPremiumSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xff1a2438).withValues(alpha: 0.96),
                    PLDesign.bgBottom.withValues(alpha: 0.99),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  left: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 36,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: PLDesign.sectionTitle.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: PLDesign.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    builder(ctx),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 20),
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
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: PLDesign.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openSearchSheet(BuildContext context, String uid) async {
  await _showPremiumSheet<void>(
    context: context,
    title: 'Search matters',
    subtitle: 'Coming soon — full-text search across all client cases',
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      child: Column(
        children: [
          _SheetTile(
            icon: Icons.search_rounded,
            accent: PLDesign.primary,
            title: 'Open notifications center',
            subtitle: 'Recent alerts across all matters',
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsCenterScreen(),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Misc helpers
// -----------------------------------------------------------------------------

String _lastActivityLabel(DateTime? t) {
  if (t == null) return 'No recent activity';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Updated just now';
  if (d.inHours < 1) return 'Updated ${d.inMinutes}m ago';
  if (d.inDays < 1) return 'Updated ${d.inHours}h ago';
  if (d.inDays < 7) return 'Updated ${d.inDays}d ago';
  return 'Updated ${DateFormat.yMMMd().format(t.toLocal())}';
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              'Could not load matters',
              style: PLDesign.sectionTitle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.\n$message',
              style: PLDesign.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
