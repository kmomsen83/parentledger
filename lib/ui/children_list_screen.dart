import 'package:flutter/material.dart';
import 'package:parentledger/l10n/context_l10n.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../design/design.dart';
import '../onboarding/onboarding_steps.dart';
import '../services/child_service.dart';

class ChildrenListScreen extends StatefulWidget {
  const ChildrenListScreen({super.key});

  @override
  State<ChildrenListScreen> createState() => _ChildrenListScreenState();
}

class _ChildrenListScreenState extends State<ChildrenListScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final ageController = TextEditingController();

  bool loading = false;
  bool continuing = false;
  String? caseId;
  String? _deletingChildId;

  @override
  void initState() {
    super.initState();
    _loadCase();
  }

  Future<void> _loadCase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;
    setState(() {
      caseId = doc.data()?['caseId'] as String?;
    });
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
      filled: true,
      fillColor: PLDesign.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  Future<void> addChild() async {
    if (loading) return;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || caseId == null) {
      _error('Missing case');
      return;
    }

    final name = nameController.text.trim();
    final age = int.parse(ageController.text.trim());

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('cases')
          .doc(caseId)
          .collection('children')
          .add({
        'name': name,
        'age': age,
        'createdAt': FieldValue.serverTimestamp(),
      });

      nameController.clear();
      ageController.clear();
      _formKey.currentState?.reset();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tTone('childAddedSuccessfully'))),
      );
    } catch (_) {
      _error('Failed to add child');
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _confirmDeleteChild({
    required String childId,
    required String name,
  }) async {
    if (caseId == null || _deletingChildId != null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PLDesign.surface,
        title: Text(context.tTone('removeChild')),
        content: Text(
          'Remove "$name" from this case? You can add them again later.',
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
      await ChildService.deleteChild(caseId: caseId!, childId: childId);
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

  Future<void> continueFlow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || caseId == null) return;

    setState(() => continuing = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cases')
          .doc(caseId)
          .collection('children')
          .get();

      if (snapshot.docs.isEmpty) {
        _error('Add at least one child to continue');
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'onboardingStep': OnboardingSteps.childrenAdded,
      });
    } catch (_) {
      _error('Could not continue');
    } finally {
      if (mounted) setState(() => continuing = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(decoration: PLDesign.screenGradient),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Your children',
                    style: PLDesign.pageTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add each child once. You can edit details later from your case.',
                    style: PLDesign.body.copyWith(height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Legal first name'),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return 'Name is required';
                            if (t.length < 2) return 'Enter at least 2 letters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Age (years)'),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return 'Age is required';
                            final n = int.tryParse(t);
                            if (n == null) return 'Use whole numbers only';
                            if (n < 0 || n > 25) return 'Enter a realistic age';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: loading ? null : addChild,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: PLDesign.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: loading
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
                  const SizedBox(height: 20),
                  if (caseId != null)
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('cases')
                            .doc(caseId)
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
                          if (docs.isEmpty) {
                            return _EmptyChildrenHint();
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final doc = docs[i];
                              final data = doc.data();
                              final childId = doc.id;
                              final name = data['name']?.toString() ?? 'Child';
                              final age = data['age'];
                              final busy = _deletingChildId == childId;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: PLDesign.elevatedCard,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: PLDesign.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.child_care_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Age $age',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (busy)
                                      const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      IconButton(
                                        tooltip: 'Remove from case',
                                        onPressed: () => _confirmDeleteChild(
                                          childId: childId,
                                          name: name,
                                        ),
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: PLDesign.danger.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: continuing ? null : continueFlow,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: const Color(0xff6366f1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: continuing
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
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChildrenHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}
