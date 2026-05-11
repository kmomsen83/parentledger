import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../design/design.dart';
import '../../services/attorney_notification_preferences.dart';
import '../entry_screen.dart';

/// Counsel profile, branding fields for PDF exports, and account controls.
class AttorneyProfileScreen extends StatefulWidget {
  const AttorneyProfileScreen({super.key});

  @override
  State<AttorneyProfileScreen> createState() => _AttorneyProfileScreenState();
}

class _AttorneyProfileScreenState extends State<AttorneyProfileScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _firm = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  final _bio = TextEditingController();
  final _bar = TextEditingController();
  final _jurisdiction = TextEditingController();
  final _logoUrl = TextEditingController();
  final _photoUrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  Map<String, bool> _notifCats = {};

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _firm.dispose();
    _email.dispose();
    _phone.dispose();
    _website.dispose();
    _address.dispose();
    _bio.dispose();
    _bar.dispose();
    _jurisdiction.dispose();
    _logoUrl.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final d = snap.data() ?? {};
    if (!mounted) return;
    setState(() {
      _firstName.text = (d['firstName'] ?? '').toString();
      _lastName.text = (d['lastName'] ?? '').toString();
      _firm.text = (d['firmName'] ?? '').toString();
      _email.text =
          (d['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '')
              .toString();
      _phone.text = (d['phone'] ?? d['phoneNumber'] ?? '').toString();
      _website.text = (d['website'] ?? d['firmWebsite'] ?? '').toString();
      _address.text = (d['address'] ?? d['firmAddress'] ?? '').toString();
      _bio.text = (d['biography'] ?? d['bio'] ?? '').toString();
      _bar.text = (d['barNumber'] ?? '').toString();
      _jurisdiction.text = (d['jurisdiction'] ?? d['barState'] ?? '').toString();
      _logoUrl.text = (d['firmLogoUrl'] ?? d['logoUrl'] ?? '').toString();
      _photoUrl.text = (d['profilePhotoUrl'] ?? d['photoURL'] ?? '').toString();
      _loading = false;
    });
    final prefs = await AttorneyNotificationPreferences.loadAll();
    if (mounted) setState(() => _notifCats = prefs);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'firstName': _firstName.text.trim(),
          'lastName': _lastName.text.trim(),
          'firmName': _firm.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'website': _website.text.trim(),
          'address': _address.text.trim(),
          'biography': _bio.text.trim(),
          'barNumber': _bar.text.trim(),
          'jurisdiction': _jurisdiction.text.trim(),
          'firmLogoUrl': _logoUrl.text.trim(),
          'profilePhotoUrl': _photoUrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const EntryScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PLDesign.background,
      appBar: AppBar(
        backgroundColor: PLDesign.surface,
        foregroundColor: PLDesign.textPrimary,
        title: const Text('Attorney profile'),
        actions: [
          TextButton(
            onPressed: _loading || _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Text(
                  'Firm & export branding',
                  style: PLDesign.sectionTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Used automatically on court-ready PDF exports.',
                  style: PLDesign.caption.copyWith(height: 1.35),
                ),
                const SizedBox(height: 16),
                _field('First name', _firstName),
                _field('Last name', _lastName),
                _field('Law firm name', _firm),
                _field('Email', _email, keyboard: TextInputType.emailAddress),
                _field('Phone', _phone, keyboard: TextInputType.phone),
                _field('Website', _website, keyboard: TextInputType.url),
                _field('Office address', _address, maxLines: 2),
                _field('Bio (short)', _bio, maxLines: 4),
                _field('Bar / license number', _bar),
                _field('Jurisdiction / state', _jurisdiction),
                _field('Profile photo URL', _photoUrl, keyboard: TextInputType.url),
                _field('Firm logo URL (PDF header)', _logoUrl,
                    keyboard: TextInputType.url),
                const SizedBox(height: 28),
                Text(
                  'Notification categories',
                  style: PLDesign.sectionTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...AttorneyNotificationPreferences.allCategories.map((c) {
                  final label = switch (c) {
                    AttorneyNotificationPreferences.catExchange =>
                      'Exchanges & check-ins',
                    AttorneyNotificationPreferences.catFlaggedMessage =>
                      'Flagged messages',
                    AttorneyNotificationPreferences.catDocument =>
                      'Document uploads',
                    AttorneyNotificationPreferences.catActivity =>
                      'Risk & activity alerts',
                    _ => c,
                  };
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(label, style: PLDesign.body),
                    value: _notifCats[c] ?? true,
                    onChanged: (v) async {
                      await AttorneyNotificationPreferences.setCategoryEnabled(
                        c,
                        v,
                      );
                      setState(() => _notifCats[c] = v);
                    },
                  );
                }),
                const SizedBox(height: 28),
                Text(
                  'Account',
                  style: PLDesign.sectionTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Sign out'),
                  onTap: _signOut,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever_outlined,
                      color: PLDesign.danger.withValues(alpha: 0.9)),
                  title: Text(
                    'Delete account',
                    style: TextStyle(color: PLDesign.danger.withValues(alpha: 0.95)),
                  ),
                  subtitle: const Text(
                    'Contact support to permanently remove a counsel workspace.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please contact ParentLedger support to delete a counsel account.',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Counsel access scope',
                  style: PLDesign.sectionTitle.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can review timelines, expenses, messages, and exports for linked matters. '
                  'You cannot post as a parent or alter protected communication history.',
                  style: PLDesign.caption.copyWith(height: 1.4),
                ),
              ],
            ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: PLDesign.body.copyWith(color: PLDesign.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: PLDesign.card,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
