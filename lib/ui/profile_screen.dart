import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/design.dart';
import '../models/user_role.dart';
import '../onboarding/onboarding_steps.dart';
import '../l10n/tone_models.dart';
import '../l10n/tone_string_resolver.g.dart';
import '../providers/case_context.dart';
import '../services/crashlytics_service.dart';
import '../services/event_coverage_validator.dart';
import '../providers/tone_preference.dart';
import '../services/firestore_fields.dart';
import '../services/premium_sync_service.dart';
import '../services/profile_media_service.dart';
import '../services/revenuecat_service.dart';
import '../services/subscription_user_firestore_sync.dart';
import '../services/server_billing_sync.dart';
import 'subscription/manage_plan_screen.dart';
import 'children_list_screen.dart';
import 'expenses_list_screen.dart';
import 'entry_screen.dart';
import 'enter_invite_code_screen.dart';
import 'help_center_screen.dart';
import 'coparent_invite_sheet.dart';
import 'invite_attorney_sheet.dart';
import '../services/invite_link_service.dart';
import 'invite_phone_sheet.dart';
import 'widgets/case_connections_section.dart';

import 'settings/refund_help_screen.dart';
import 'widgets/us_phone_input_formatter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  double _uploadProgress = 0;
  bool _uploading = false;
  Map<String, dynamic>? _inviteStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshInviteStatus());
  }

  Future<void> _refreshInviteStatus() async {
    final m = await _loadInviteConnectionStatus();
    if (mounted) setState(() => _inviteStatus = m);
  }

  /// Uses case [memberIds] (not legacy `members` subcollection).
  Future<Map<String, dynamic>> _loadInviteConnectionStatus() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    final userDoc = await db.collection('users').doc(uid).get();
    final caseId = userDoc.data()?['caseId'] as String?;
    if (caseId == null) {
      return {'status': 'none'};
    }

    final caseSnap = await db.collection('cases').doc(caseId).get();
    final members = FirestoreFields.readCaseMemberIds(caseSnap.data() ?? {});
    final others = members.where((id) => id != uid).toList();
    if (others.isNotEmpty) {
      final od = await db.collection('users').doc(others.first).get();
      final name = _displayNameFromUserDoc(od.data());
      return {'status': 'connected', 'name': name};
    }

    final invites = await db
        .collection('caseInvites')
        .where('fromUserId', isEqualTo: uid)
        .where('caseId', isEqualTo: caseId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (invites.docs.isNotEmpty) {
      final doc = invites.docs.first;
      final data = doc.data();
      return {
        'status': 'pending',
        'inviteId': doc.id,
        'toPhone': data['toPhone']?.toString(),
        'role': data['role']?.toString() ?? 'coparent',
      };
    }

    return {'status': 'none'};
  }

  static String _displayNameFromUserDoc(Map<String, dynamic>? d) {
    if (d == null) return 'Co-parent';
    final dn = (d['displayName'] ?? '').toString().trim();
    if (dn.isNotEmpty) return dn;
    final fn = (d['firstName'] ?? '').toString().trim();
    final ln = (d['lastName'] ?? '').toString().trim();
    final full = '$fn $ln'.trim();
    if (full.isNotEmpty) return full;
    return 'Co-parent';
  }

  void _popOrOpenDashboard() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  static String _profileRoleLabel(Map<String, dynamic> d) {
    final r = (d['role'] ?? '').toString().toLowerCase();
    if (r == 'attorney') return 'Attorney';
    final pt = (d['parentType'] ?? '').toString().toLowerCase();
    if (pt == 'mom') return 'Mother';
    if (pt == 'dad') return 'Father';
    if (pt == 'guardian') return 'Guardian';
    final g = (d['gender'] ?? '').toString().toLowerCase();
    if (g == 'male' || g == 'm') return 'Father';
    if (g == 'female' || g == 'f') return 'Mother';
    return 'Parent';
  }

  Future<void> _pickPhoto() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: PLDesign.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: PLDesign.primary),
              title: Text(context.tTone('takePhoto')),
              onTap: () {
                Navigator.pop(ctx);
                _handlePick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: PLDesign.primary),
              title: Text(context.tTone('chooseFromGallery')),
              onTap: () {
                Navigator.pop(ctx);
                _handlePick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop Photo'),
        ],
      );
    } on PlatformException catch (e, st) {
      if (kDebugMode) {
        debugPrint('image_cropper failed: $e\n$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tTone('uploadFailed'),
          ),
        ),
      );
      return;
    }

    if (cropped == null) return;
    await _uploadPhoto(File(cropped.path));
  }

  Future<void> _uploadPhoto(File file) async {
    try {
      setState(() {
        _uploading = true;
        _uploadProgress = 0;
      });

      await ProfileMediaService.uploadAvatarJpeg(
        file,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _uploadProgress = p);
        },
      );
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('profilePhotoUpdated'))),
      );
    } on FirebaseException catch (e) {
      // storage/canceled — user backed out, UCrop/activity teardown, or task.cancel().
      // Native logs often show Code -13040 / "The operation was cancelled".
      if (mounted) setState(() => _uploading = false);
      if (e.code == 'storage/canceled' || e.code == 'canceled') {
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tTone('uploadFailed'))),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _uploading = false);
      final silent = e.toString().toLowerCase().contains('cancel');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tTone('uploadFailed'))),
        );
      }
    }
  }

  Future<void> _showAccountTypePicker(
    BuildContext context,
    CaseContext session,
  ) async {
    final chosen = await showDialog<UserRole>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: Text(
          'Account type',
          style: PLDesign.sectionTitle.copyWith(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose how ParentLedger is optimized for you. You can change this anytime.',
              style: PLDesign.caption.copyWith(
                color: PLDesign.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.person_rounded, color: PLDesign.primary),
              title: const Text('Parent'),
              subtitle: const Text('Custody, messages, expenses'),
              onTap: () => Navigator.pop(ctx, UserRole.parent),
            ),
            ListTile(
              leading: Icon(Icons.balance_rounded, color: PLDesign.primary),
              title: const Text('Attorney'),
              subtitle: const Text('Client matters and documents'),
              onTap: () => Navigator.pop(ctx, UserRole.attorney),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (chosen == null || !context.mounted || chosen == session.userRole) {
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      if (chosen == UserRole.attorney) {
        await ref.set(<String, dynamic>{
          'role': 'attorney',
          'accountType': 'attorney',
          'onboardingStep': OnboardingSteps.onboardingComplete,
        }, SetOptions(merge: true));
        await ServerBillingSync.applyCounselSubscriptionDefaults();
      } else {
        await ref.set(<String, dynamic>{
          'role': 'parent',
          'accountType': 'parent',
          'onboardingStep': OnboardingSteps.onboardingComplete,
        }, SetOptions(merge: true));
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chosen == UserRole.attorney
                ? 'Switched to attorney workspace.'
                : 'Switched to parent home.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update account type: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const EntryScreen()),
      (_) => false,
    );
  }

  Future<void> _restorePurchases() async {
    final cx = context.read<CaseContext>();
    if (cx.isAttorney) return;
    try {
      await Purchases.restorePurchases();
      final active = await RevenueCatService.hasProEntitlement();
      if (!mounted) return;
      if (active) {
        await PremiumSyncService.syncPremiumWithBackend();
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final info = await Purchases.getCustomerInfo();
          await SubscriptionUserFirestoreSync.applyProEntitlement(
            info: info,
            planKey: 'restore',
            onboardingStep: OnboardingSteps.subscribed,
          );
          await SubscriptionUserFirestoreSync.syncTrialConsumptionFromCustomerInfo(
            info,
          );
        }
        await cx.refreshPremiumStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membership is active — your records stay organized.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active membership found for this account.'),
          ),
        );
      }
    } catch (e, st) {
      await CrashlyticsService.recordError(
        e,
        st,
        reason: 'profile_restore_purchases',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore failed. Check your connection and try again.'),
          ),
        );
      }
    }
  }

  Future<void> _openSubscriptionManagement() async {
    final openedCustomerCenter =
        await RevenueCatService.presentCustomerCenter();
    if (openedCustomerCenter) return;

    final uri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tTone('couldNotOpenSubscriptionSettings'))),
      );
    }
  }

  Future<void> _cancelPendingInvite(String inviteId) async {
    try {
      await FirebaseFirestore.instance
          .collection('caseInvites')
          .doc(inviteId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tTone('inviteCancelled'))),
        );
        await _refreshInviteStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: PLDesign.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: PLDesign.textPrimary,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _popOrOpenDashboard,
          ),
          title: Text(
            'Profile',
            style: PLDesign.sectionTitle.copyWith(
              color: PLDesign.textPrimary,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(child: Text(context.tTone('notSignedIn'))),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: PLDesign.textPrimary,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _popOrOpenDashboard,
        ),
        title: Text(
          'Profile',
          style: PLDesign.sectionTitle.copyWith(
            color: PLDesign.textPrimary,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: PLDesign.primary,
        unselectedItemColor: PLDesign.textMuted,
        backgroundColor: PLDesign.surface,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 0) {
            _popOrOpenDashboard();
          } else if (i == 1) {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ExpensesListScreen(),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_rounded),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/design/premium_entry_screen_background.png',
            fit: BoxFit.cover,
          ),
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.45),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                left: 20,
                right: 20,
              ),
              child: RefreshIndicator(
                color: PLDesign.primary,
                onRefresh: _refreshInviteStatus,
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .snapshots(),
                  builder: (context, userSnap) {
                    if (!userSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final d = userSnap.data!.data() ?? {};
                    final session = context.watch<CaseContext>();
                    final caseId = (d['caseId'] ?? '').toString().trim();
                    final firstName = (d['firstName'] ?? '').toString();
                    final lastName = (d['lastName'] ?? '').toString();
                    final fullName = '$firstName $lastName'.trim().isEmpty
                        ? 'Parent'
                        : '$firstName $lastName'.trim();
                    final photoUrl =
                        (d['profilePhotoUrl'] ?? d['photoUrl']) as String?;
                    final roleLabel = _profileRoleLabel(d);

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      _ProfileHeader(
                        fullName: fullName,
                        roleLabel: roleLabel,
                        photoUrl: photoUrl,
                        initials: fullName.isNotEmpty
                            ? fullName[0].toUpperCase()
                            : '?',
                        uploading: _uploading,
                        uploadProgress: _uploadProgress,
                        onAvatarTap: _pickPhoto,
                      ),
                      const SizedBox(height: 20),
                      if (!session.isAttorney) ...[
                        _SectionTitle('Family'),
                        const SizedBox(height: 10),
                        _ProfileTile(
                          icon: Icons.child_care_rounded,
                          title: 'Children',
                          subtitle: 'Profiles & custody context',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const ChildrenListScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        _SectionTitle('Connections'),
                        const SizedBox(height: 10),
                        if (caseId.isNotEmpty)
                          CaseConnectionsSection(
                            caseId: caseId,
                            canManageConnections: true,
                          ),
                        if (caseId.isNotEmpty) const SizedBox(height: 14),
                        if (_inviteStatus != null) _inviteBanner(context),
                        _ProfileTile(
                          icon: Icons.person_add_alt_1_rounded,
                          title: 'Invite Co-Parent',
                          subtitle: 'Invite code & link (recommended)',
                          onTap: () => showCoparentInviteSheet(context)
                              .then((_) => _refreshInviteStatus()),
                        ),
                        const SizedBox(height: 12),
                        _ProfileTile(
                          icon: Icons.gavel_rounded,
                          title: 'Invite Attorney',
                          subtitle: 'Shareable link — read-only case access',
                          onTap: () => showInviteAttorneySheet(context),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _ProfileTile(
                        icon: Icons.pin_outlined,
                        title: 'Enter Invite Code',
                        subtitle: 'Join with co-parent code or legacy invite',
                        onTap: () {
                          final pre =
                              InviteLinkService.pendingInviteCode.value;
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => EnterInviteCodeScreen(
                                initialCode: pre,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _ProfileTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Help & Support',
                        subtitle: 'Get help, chat support, and FAQs',
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const HelpCenterScreen(),
                            ),
                          );
                        },
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 12),
                        _ProfileTile(
                          icon: Icons.fact_check_outlined,
                          title: 'Validate Case Logging',
                          subtitle: 'Debug: compare activity vs caseEvents',
                          onTap: () async {
                            final caseId =
                                context.read<CaseContext>().caseId?.trim();
                            if (caseId == null || caseId.isEmpty) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No case on this account.'),
                                ),
                              );
                              return;
                            }
                            final report = await EventCoverageValidator
                                .validateRecentActivity(caseId);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  report.skipped
                                      ? 'Coverage validator skipped.'
                                      : 'Logging check: ${report.mismatches} '
                                          'mismatch(es) of ${report.actionsChecked} '
                                          'actions — see console.',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 22),
                      _SectionTitle(context.tTone('uxTonePreferenceTitle')),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: DropdownButtonFormField<UiTone>(
                          key: ValueKey<UiTone>(
                            context.watch<TonePreference>().tone,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: PLDesign.card,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: PLDesign.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: PLDesign.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                          ),
                          initialValue: context.watch<TonePreference>().tone,
                          items: [
                            DropdownMenuItem(
                              value: UiTone.neutral,
                              child: Text(
                                toneString(
                                  context.l10n,
                                  'uxToneNeutralOption',
                                  UiTone.neutral,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: UiTone.professional,
                              child: Text(
                                toneString(
                                  context.l10n,
                                  'uxToneProfessionalOption',
                                  UiTone.professional,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: UiTone.legal,
                              child: Text(
                                toneString(
                                  context.l10n,
                                  'uxToneLegalOption',
                                  UiTone.legal,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              context.read<TonePreference>().setTone(v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 22),
                      _SectionTitle('Subscription'),
                      const SizedBox(height: 10),
                      if (session.isAttorney)
                        const _AttorneyProfessionalAccessCard()
                      else ...[
                        _SubscriptionPanel(
                          onManage: () async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const ManagePlanScreen(),
                              ),
                            );
                          },
                          onCancel: _openSubscriptionManagement,
                          onRestore: _restorePurchases,
                        ),
                        const SizedBox(height: 12),
                        _ProfileTile(
                          icon: Icons.receipt_long_rounded,
                          title: 'Billing & Refunds',
                          subtitle: 'Subscription and refund support',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const RefundHelpScreen(),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _SectionTitle('Account'),
                      const SizedBox(height: 10),
                      _ProfileTile(
                        icon: Icons.badge_outlined,
                        title: 'Account type',
                        subtitle: session.isAttorney
                            ? 'Attorney — counsel workspace'
                            : 'Parent — family workspace',
                        onTap: () => _showAccountTypePicker(context, session),
                      ),
                      const SizedBox(height: 12),
                      _ProfileTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign Out',
                        subtitle: 'Securely exit ParentLedger',
                        onTap: _logout,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _inviteBanner(BuildContext context) {
    final s = _inviteStatus;
    if (s == null) return const SizedBox.shrink();

    if (s['status'] == 'connected') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _ProfileNotice(
          icon: Icons.verified_rounded,
          title: 'Co-parent connected',
          subtitle: s['name']?.toString() ?? '',
        ),
      );
    }

    if (s['status'] == 'pending') {
      final inviteId = s['inviteId'] as String?;
      final phone = s['toPhone'] as String?;
      final role = s['role'] as String? ?? 'coparent';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PLDesign.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PLDesign.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      color: PLDesign.warning, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Invite sent',
                      style: PLDesign.sectionTitle.copyWith(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tap to resend or cancel',
                style: PLDesign.caption.copyWith(height: 1.3),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: inviteId == null
                        ? null
                        : () => _cancelPendingInvite(inviteId),
                    child: Text(context.tTone('cancelInvite')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final formatted = e164ToUsDisplay(phone);
                      showInvitePhoneSheet(
                        context,
                        role: role,
                        initialFormattedPhone: formatted,
                      ).then((_) => _refreshInviteStatus());
                    },
                    child: Text(context.tTone('resend')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: PLDesign.caption.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: PLDesign.textMuted,
      ),
    );
  }
}

class _ProfileNotice extends StatelessWidget {
  const _ProfileNotice({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PLDesign.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PLDesign.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: PLDesign.success, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: PLDesign.sectionTitle.copyWith(fontSize: 16)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: PLDesign.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.fullName,
    required this.roleLabel,
    required this.photoUrl,
    required this.initials,
    required this.uploading,
    required this.uploadProgress,
    required this.onAvatarTap,
  });

  final String fullName;
  final String roleLabel;
  final String? photoUrl;
  final String initials;
  final bool uploading;
  final double uploadProgress;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: PLDesign.legalGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff26324d)),
        boxShadow: PLDesign.softShadow,
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAvatarTap,
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: PLDesign.primary.withValues(alpha: 0.2),
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl!) : null,
                    child: photoUrl == null
                        ? Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: PLDesign.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 16, color: Colors.white),
                ),
              ),
              if (uploading)
                SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    value: uploadProgress > 0 && uploadProgress < 1
                        ? uploadProgress
                        : null,
                    strokeWidth: 3,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            fullName,
            style: PLDesign.heroTitle.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            roleLabel,
            style: PLDesign.caption.copyWith(
              fontSize: 14,
              color: PLDesign.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
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
      color: PLDesign.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: PLDesign.primary, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PLDesign.sectionTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: PLDesign.caption.copyWith(height: 1.25),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: PLDesign.textMuted.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttorneyProfessionalAccessCard extends StatelessWidget {
  const _AttorneyProfessionalAccessCard();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaseContext>();
    final flags = session.entitlementFlags;
    final preview = flags.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .take(6)
        .join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PLDesign.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PLDesign.border),
        boxShadow: PLDesign.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attorney Professional Access',
            style: PLDesign.sectionTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Counsel workspace is enabled. Store billing and parent subscription '
            'options are hidden — you have full professional access to case tools.',
            style: PLDesign.caption.copyWith(height: 1.35),
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Active capabilities',
              style: PLDesign.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: PLDesign.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              preview,
              style: PLDesign.caption.copyWith(height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubscriptionPanel extends StatelessWidget {
  const _SubscriptionPanel({
    required this.onManage,
    required this.onCancel,
    required this.onRestore,
  });

  final Future<void> Function() onManage;
  final Future<void> Function() onCancel;
  final Future<void> Function() onRestore;

  static String _planTitle(
    EntitlementInfo? active,
    EntitlementInfo? anyEnt,
    bool hasActive,
  ) {
    if (hasActive && active != null) {
      switch (active.periodType) {
        case PeriodType.trial:
          return 'Free Trial';
        case PeriodType.intro:
        case PeriodType.normal:
        case PeriodType.prepaid:
        case PeriodType.unknown:
          return 'Pro';
      }
    }
    if (anyEnt != null && !anyEnt.isActive) {
      return 'Expired';
    }
    return 'Not subscribed';
  }

  static String? _billingLine(EntitlementInfo? e, bool hasActive) {
    if (!hasActive || e == null) return null;
    final raw = e.expirationDate;
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    final fmt = DateFormat.yMMMd().add_jm();
    if (e.willRenew == true) {
      return 'Next billing · ${fmt.format(dt)}';
    }
    return 'Access ends · ${fmt.format(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomerInfo>(
      future: Purchases.getCustomerInfo(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final info = snap.data;
        final id = CaseContext.premiumEntitlementId;
        final active = info?.entitlements.active[id];
        final hasActive = active != null;
        final anyEnt = info?.entitlements.all[id];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PLDesign.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PLDesign.border),
            boxShadow: PLDesign.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current plan',
                style: PLDesign.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: PLDesign.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _planTitle(active, anyEnt, hasActive),
                style: PLDesign.sectionTitle.copyWith(fontSize: 20),
              ),
              if (_billingLine(active, hasActive) != null) ...[
                const SizedBox(height: 8),
                Text(
                  _billingLine(active, hasActive)!,
                  style: PLDesign.caption.copyWith(height: 1.35),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onManage(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: PLDesign.border),
                        foregroundColor: PLDesign.textPrimary,
                      ),
                      child: Text(context.tTone('managePlan')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onCancel(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: PLDesign.surface,
                        foregroundColor: PLDesign.textPrimary,
                      ),
                      child: Text(context.tTone('cancelSubscription')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => onRestore(),
                  child: const Text('Restore purchases'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
