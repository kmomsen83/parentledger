import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../providers/case_context.dart';
import '../../services/profile_media_service.dart';
import '../enter_invite_code_screen.dart';

/// Multi-step counsel onboarding — isolated from parent custody / RevenueCat flows.
class AttorneyOnboardingScreen extends StatefulWidget {
  const AttorneyOnboardingScreen({super.key});

  @override
  State<AttorneyOnboardingScreen> createState() =>
      _AttorneyOnboardingScreenState();
}

class _AttorneyOnboardingScreenState extends State<AttorneyOnboardingScreen> {
  static const int _pageCount = 8;

  final _pageController = PageController();
  int _index = 0;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _firm = TextEditingController();
  final _jurisdiction = TextEditingController();
  final _bar = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _website = TextEditingController();
  final _bio = TextEditingController();

  File? _pickedPhoto;
  bool _loading = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    final phone = u?.phoneNumber;
    if (phone != null && phone.isNotEmpty) {
      _phone.text = phone;
    }
    final em = u?.email;
    if (em != null && em.isNotEmpty) {
      _email.text = em;
    }
    final dn = u?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) {
      final parts = dn.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) _firstName.text = parts.first;
      if (parts.length > 1) _lastName.text = parts.sublist(1).join(' ');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _firm.dispose();
    _jurisdiction.dispose();
    _bar.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _website.dispose();
    _bio.dispose();
    super.dispose();
  }

  double get _progress => (_index + 1) / _pageCount;

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
            color: PLDesign.primary.withValues(alpha: 0.95), width: 1.4),
      ),
    );
  }

  bool _validateCurrent() {
    switch (_index) {
      case 1:
        if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
          _toast('Enter your first and last name');
          return false;
        }
        return true;
      case 4:
        if (_email.text.trim().isEmpty) {
          _toast('Enter your professional email');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _next() async {
    if (!_validateCurrent()) return;
    HapticFeedback.lightImpact();
    if (_index >= _pageCount - 1) return;
    final next = _index + 1;
    await _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    if (mounted) setState(() => _index = next);
  }

  Future<void> _back() async {
    HapticFeedback.selectionClick();
    if (_index <= 0) return;
    final prev = _index - 1;
    await _pageController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (mounted) setState(() => _index = prev);
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() => _pickedPhoto = File(picked.path));
    HapticFeedback.selectionClick();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      _toast('Enter your first and last name');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      String? photoUrl;
      if (_pickedPhoto != null) {
        setState(() => _uploadingPhoto = true);
        try {
          photoUrl = await ProfileMediaService.uploadAvatarJpeg(_pickedPhoto!);
        } finally {
          if (mounted) setState(() => _uploadingPhoto = false);
        }
      }

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('completeAttorneyOnboarding');
      await callable.call(<String, dynamic>{
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'firmName': _firm.text.trim(),
        'barNumber': _bar.text.trim(),
        'attorneyEmail': _email.text.trim(),
        'phone': _phone.text.trim(),
        'officeAddress': _address.text.trim(),
        'website': _website.text.trim(),
        'attorneyBio': _bio.text.trim(),
        'jurisdiction': _jurisdiction.text.trim(),
        if (photoUrl != null && photoUrl.isNotEmpty)
          'profilePhotoUrl': photoUrl,
      });
      if (!mounted) return;
      await context.read<CaseContext>().refreshUserDocFromServer();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        _toast(e.message ?? 'Could not save profile');
      }
    } catch (e) {
      if (mounted) _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openInviteCode() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const EnterInviteCodeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(decoration: PLDesign.screenGradient),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (_index > 0)
                        IconButton(
                          onPressed: _loading ? null : _back,
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          color: Colors.white,
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: Semantics(
                          label: 'Onboarding step ${_index + 1} of $_pageCount',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 5,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                PLDesign.primary.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _index = i),
                      children: [
                        const _WelcomePage(),
                        _ScrollPage(
                          bottomInset: bottom,
                          children: [
                            _pageTitle('Your name',
                                'Shown to clients and on exports.'),
                            TextField(
                              controller: _firstName,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(color: Colors.white),
                              decoration: _decoration('First name'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _lastName,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(color: Colors.white),
                              decoration: _decoration('Last name'),
                            ),
                          ],
                        ),
                        _ScrollPage(
                          bottomInset: bottom,
                          children: [
                            _pageTitle('Law firm',
                                'Optional — you can update this anytime.'),
                            TextField(
                              controller: _firm,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(color: Colors.white),
                              decoration: _decoration('Firm name'),
                            ),
                          ],
                        ),
                        _ScrollPage(
                          bottomInset: bottom,
                          children: [
                            _pageTitle('Practice & credentials',
                                'Helps clients recognize your jurisdiction.'),
                            TextField(
                              controller: _jurisdiction,
                              textCapitalization: TextCapitalization.words,
                              style: const TextStyle(color: Colors.white),
                              decoration: _decoration('State / jurisdiction'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _bar,
                              style: const TextStyle(color: Colors.white),
                              decoration:
                                  _decoration('Bar number / license ID'),
                            ),
                          ],
                        ),
                        _ScrollPage(
                          bottomInset: bottom,
                          children: [
                            _pageTitle('Contact',
                                'How clients and co-counsel reach you.'),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: _decoration('Attorney email'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: Colors.white),
                              decoration: _decoration('Phone number'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _address,
                              maxLines: 2,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(color: Colors.white),
                              decoration: _decoration('Office address'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _website,
                              keyboardType: TextInputType.url,
                              style: const TextStyle(color: Colors.white),
                              decoration: _decoration('Website (optional)'),
                            ),
                          ],
                        ),
                        _ScrollPage(
                          bottomInset: bottom,
                          children: [
                            _pageTitle('Professional bio',
                                'Optional — a short paragraph is enough.'),
                            TextField(
                              controller: _bio,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(color: Colors.white),
                              decoration: _decoration('Bio'),
                            ),
                          ],
                        ),
                        _ScrollPage(
                          bottomInset: bottom,
                          children: [
                            _pageTitle('Photo or firm logo',
                                'Optional — builds trust on shared matters.'),
                            if (_pickedPhoto != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  _pickedPhoto!,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                height: 120,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Text(
                                  'No image selected',
                                  style: PLDesign.body
                                      .copyWith(color: Colors.white54),
                                ),
                              ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _uploadingPhoto ? null : _pickPhoto,
                              icon: const Icon(
                                  Icons.add_photo_alternate_outlined),
                              label: Text(_pickedPhoto == null
                                  ? 'Choose image'
                                  : 'Replace image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.35)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 18),
                              ),
                            ),
                          ],
                        ),
                        _ScrollPage(
                          bottomInset: bottom,
                          children: [
                            _pageTitle('Your counsel workspace',
                                'Designed for matter-based review — not co-parent scheduling.'),
                            const SizedBox(height: 8),
                            _bullet(
                                'Client cases, timelines, and documents in one place'),
                            _bullet(
                                'Exports and communication tools built for legal workflows'),
                            _bullet(
                                'No parenting subscription — your access is counsel-grade'),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: _loading ? null : _openInviteCode,
                              child: Text(
                                'Have a client invite code?',
                                style: PLDesign.body.copyWith(
                                  color:
                                      PLDesign.primary.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 10, 0, 16 + bottom),
                    child: _index < _pageCount - 1
                        ? PLDesign.primaryButton(
                            label: 'Continue',
                            onTap: _loading ? () {} : _next,
                          )
                        : PLDesign.primaryButton(
                            label: _loading
                                ? (_uploadingPhoto
                                    ? 'Uploading photo…'
                                    : 'Finishing…')
                                : 'Complete setup',
                            onTap: _loading ? () {} : _submit,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PLDesign.heroTitle.copyWith(fontSize: 26, height: 1.15),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: PLDesign.body.copyWith(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 20, color: PLDesign.primary.withValues(alpha: 0.9)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: PLDesign.body.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome, counsel',
                  style:
                      PLDesign.heroTitle.copyWith(fontSize: 30, height: 1.12),
                ),
                const SizedBox(height: 14),
                Text(
                  'We will set up your professional profile in a few calm steps. '
                  'This workspace stays separate from co-parent onboarding.',
                  style: PLDesign.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.45,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScrollPage extends StatelessWidget {
  const _ScrollPage({
    required this.children,
    required this.bottomInset,
  });

  final List<Widget> children;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, 12, 0, 24 + bottomInset),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
