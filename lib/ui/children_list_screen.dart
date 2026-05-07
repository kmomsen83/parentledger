import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:parentledger/l10n/context_l10n.dart';

import '../design/design.dart';
import '../models/child_model.dart';
import '../onboarding/onboarding_steps.dart';
import '../services/child_service.dart';

/// Circular child avatar: [NetworkImage] when [imageUrl] is non-empty, else [Icons.child_care].
Widget buildChildAvatar(String? imageUrl, {double radius = 26}) {
  final url = imageUrl?.trim();
  final hasPhoto = url != null && url.isNotEmpty;
  final double diameter = radius * 2;

  final Widget fallbackIcon = Icon(
    Icons.child_care,
    color: Colors.white.withValues(alpha: 0.9),
    size: radius * 1.15,
  );

  if (!hasPhoto) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: PLDesign.surface,
      child: fallbackIcon,
    );
  }

  return CircleAvatar(
    radius: radius,
    backgroundColor: PLDesign.surface,
    child: ClipOval(
      child: Image(
        image: NetworkImage(url),
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: PLDesign.surface,
          child: Center(child: fallbackIcon),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: diameter,
            height: diameter,
            child: Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PLDesign.primary.withValues(alpha: 0.9),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class ChildListItem extends StatelessWidget {
  const ChildListItem({
    super.key,
    required this.child,
    required this.ageLabel,
    required this.onTapEdit,
    required this.onDelete,
    this.deleting = false,
  });

  final ChildModel child;
  final String ageLabel;
  final VoidCallback onTapEdit;
  final VoidCallback onDelete;
  final bool deleting;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: PLDesign.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: _radius,
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: onTapEdit,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    buildChildAvatar(child.photoUrl, radius: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            child.name.isNotEmpty ? child.name : 'Child',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ageLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (deleting)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Remove from case',
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.withValues(alpha: 0.9),
              ),
            ),
        ],
      ),
    );

    return KeyedSubtree(
      key: ValueKey<String>(child.id),
      child: card
          .animate()
          .fadeIn(duration: 220.ms, curve: Curves.easeOut)
          .slideY(
            begin: 0.05,
            end: 0,
            duration: 220.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}

class ChildrenListScreen extends StatefulWidget {
  const ChildrenListScreen({super.key});

  @override
  State<ChildrenListScreen> createState() => _ChildrenListScreenState();
}

class _ChildrenListScreenState extends State<ChildrenListScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  bool _loading = false;
  bool _continuing = false;
  String? _caseId;
  String? _deletingChildId;

  @override
  void initState() {
    super.initState();
    _loadCase();
  }

  Future<void> _loadCase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!mounted) return;
    setState(() {
      _caseId = doc.data()?['caseId'] as String?;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
      filled: true,
      fillColor: PLDesign.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PLDesign.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PLDesign.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xff4f7cff), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PLDesign.danger.withValues(alpha: 0.8)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: PLDesign.danger.withValues(alpha: 0.9)),
      ),
    );
  }

  /// Label from stored `age` on the doc, or computed from DOB when present.
  static String _ageLabel(ChildModel child, Map<String, dynamic> raw) {
    final ageVal = raw['age'];
    if (ageVal is int) return 'Age $ageVal';
    if (ageVal is num) return 'Age ${ageVal.toInt()}';
    if (ageVal != null) return 'Age $ageVal';
    final fromDob = child.age;
    if (fromDob != null) return 'Age $fromDob';
    return 'Age —';
  }

  Future<void> _addChild() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = FirebaseAuth.instance.currentUser;
    final cid = _caseId;
    if (user == null || cid == null) {
      _showError('Missing case');
      return;
    }

    final name = _nameController.text.trim();
    final ageParsed = int.tryParse(_ageController.text.trim());
    if (name.isEmpty || ageParsed == null) return;

    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('cases')
          .doc(cid)
          .collection('children')
          .add({
        'name': name,
        'age': ageParsed,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _nameController.clear();
      _ageController.clear();
      _formKey.currentState?.reset();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('childAddedSuccessfully'))),
      );
    } catch (_) {
      _showError('Failed to add child');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDeleteChild({
    required String childId,
    required String name,
  }) async {
    final cid = _caseId;
    if (cid == null || _deletingChildId != null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: Text(context.tTone('removeChild')),
        content: const Text(
          'Are you sure you want to remove this child?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tTone('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: PLDesign.danger),
            child: Text(context.tTone('remove')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deletingChildId = childId);
    try {
      await ChildService.deleteChild(caseId: cid, childId: childId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('permission')
                ? 'You don’t have permission to remove a child on this account.'
                : 'Could not remove child. Try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingChildId = null);
    }
  }

  Future<void> _continueFlow() async {
    final user = FirebaseAuth.instance.currentUser;
    final cid = _caseId;
    if (user == null || cid == null) return;

    setState(() => _continuing = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cases')
          .doc(cid)
          .collection('children')
          .get();

      if (snapshot.docs.isEmpty) {
        _showError('Add at least one child to continue');
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'onboardingStep': OnboardingSteps.childrenAdded,
      });
    } catch (_) {
      _showError('Could not continue');
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const EdgeInsets pagePadding =
        EdgeInsets.symmetric(horizontal: 18, vertical: 8);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        title: Text(
          context.tTone('yourChildren'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: DecoratedBox(
        decoration: PLDesign.screenGradient,
        child: SafeArea(
          child: Padding(
            padding: pagePadding.copyWith(
              bottom: pagePadding.vertical + 4,
              top: 4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add each child once. You can edit details later from your case.',
                  style: PLDesign.body.copyWith(height: 1.35),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Legal first name'),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return 'Name cannot be empty';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Age (years)'),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return 'Age is required';
                          if (int.tryParse(t) == null) {
                            return 'Age must be a number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _addChild,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: PLDesign.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(context.tTone('addChild')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_caseId == null)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('cases')
                          .doc(_caseId)
                          .collection('children')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final docs = snap.data!.docs;
                        final hasChildren = docs.isNotEmpty;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: docs.isEmpty
                                  ? const _EmptyChildrenHint()
                                  : ListView.separated(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      itemCount: docs.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, i) {
                                        final doc = docs[i];
                                        final data = doc.data();
                                        final child = ChildModel.fromMap(
                                          doc.id,
                                          data,
                                          caseId: _caseId,
                                        );
                                        final name =
                                            data['name']?.toString() ??
                                                child.name;
                                        final toEdit =
                                            child.copyWith(name: name);
                                        final busy = _deletingChildId == doc.id;

                                        return ChildListItem(
                                          child: toEdit,
                                          ageLabel: _ageLabel(child, data),
                                          deleting: busy,
                                          onTapEdit: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/editChild',
                                              arguments: toEdit,
                                            );
                                          },
                                          onDelete: () =>
                                              _confirmDeleteChild(
                                            childId: doc.id,
                                            name: name.isNotEmpty
                                                ? name
                                                : 'Child',
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _continuing || !hasChildren
                                  ? null
                                  : _continueFlow,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(54),
                                backgroundColor: PLDesign.primary,
                                disabledBackgroundColor: PLDesign.primary
                                    .withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _continuing
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
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

class _EmptyChildrenHint extends StatelessWidget {
  const _EmptyChildrenHint();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.groups_2_outlined,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add at least one child to continue',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use the form above. You need at least one child on file to finish setup.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
