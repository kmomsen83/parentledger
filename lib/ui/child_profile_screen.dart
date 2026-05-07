import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/child_model.dart';
import '../providers/case_context.dart';
import '../services/child_service.dart';
import 'add_edit_child_screen.dart';

/// Display optional Firestore text fields — empty/null → [emptyLabel].
String _fieldOrLabel(String? value, {required String emptyLabel}) {
  final t = value?.trim();
  if (t == null || t.isEmpty) return emptyLabel;
  return t;
}

class ChildProfileScreen extends StatefulWidget {
  final ChildModel child;

  const ChildProfileScreen({
    super.key,
    required this.child,
  });

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  bool uploading = false;
  String? localImagePath;

  static int _ageFromDob(DateTime? dob) {
    if (dob == null) return 0;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// 📸 PICK SOURCE
  Future<void> pickPhoto() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _handlePick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _handlePick(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 📸 HANDLE PICK + UPLOAD
  Future<void> _handlePick(ImageSource source) async {
    try {
      final caseId = context.read<CaseContext>().caseId;

      if (caseId == null) return;

      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);

      if (picked == null) return;

      setState(() {
        uploading = true;
        localImagePath = picked.path;
      });

      final file = File(picked.path);

      final ref = FirebaseStorage.instance
          .ref('cases/$caseId/children/${widget.child.id}.jpg');

      await ref.putFile(file);

      final url = await ref.getDownloadURL();

      await ChildService.updateChildPartial(
        caseId: caseId,
        childId: widget.child.id,
        data: {
          'photoUrl': url,
        },
      );

      if (!mounted) return;

      setState(() => localImagePath = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo updated')),
      );
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Upload failed');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed')),
        );
      }
    }

    if (mounted) {
      setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caseId = context.watch<CaseContext>().caseId;

    if (caseId == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Link your workspace to view this profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<ChildModel?>(
      stream: ChildService.watchChild(caseId, widget.child.id),
      builder: (context, snapshot) {
        final child = snapshot.data ?? widget.child;

        return Scaffold(
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'lib/design/premium_entry_screen_background.png',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            const Text(
                              'Child Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        AddEditChildScreen(initialChild: child),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: pickPhoto,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff76c3ff),
                                    Color(0xff3d7cff),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withValues(alpha: 0.4),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: localImagePath != null
                                    ? Image.file(
                                        File(localImagePath!),
                                        fit: BoxFit.cover,
                                      )
                                    : child.photoUrl != null &&
                                            child.photoUrl!.isNotEmpty
                                        ? Image.network(
                                            child.photoUrl!,
                                            fit: BoxFit.cover,
                                          )
                                        : Center(
                                            child: Text(
                                              child.name.isNotEmpty
                                                  ? child.name
                                                      .substring(0, 1)
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 50,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black87,
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 18,
                                ),
                              ),
                            ),
                            if (uploading)
                              Positioned.fill(
                                child: ClipOval(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 6,
                                      sigmaY: 6,
                                    ),
                                    child: Container(
                                      color: Colors.black38,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        child.name,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (child.dob != null)
                        Text(
                          'Age ${_ageFromDob(child.dob)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      const SizedBox(height: 26),
                      _InfoCard(
                        title: 'School',
                        value: _fieldOrLabel(child.school,
                            emptyLabel: 'Not added'),
                      ),
                      _InfoCard(
                        title: 'Grade',
                        value: _fieldOrLabel(child.grade,
                            emptyLabel: 'Not added'),
                      ),
                      _InfoCard(
                        title: 'Activities',
                        value: _fieldOrLabel(child.activities,
                            emptyLabel: 'Not added'),
                      ),
                      _InfoCard(
                        title: 'Medical Notes',
                        value: _fieldOrLabel(child.medicalNotes,
                            emptyLabel: 'None'),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;

  const _InfoCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
