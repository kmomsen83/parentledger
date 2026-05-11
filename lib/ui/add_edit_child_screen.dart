import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/case_context.dart';
import '../services/child_private_photo_service.dart';
import '../services/child_service.dart';
import '../models/child_model.dart';
import '../design/design.dart';
import 'children_list_screen.dart';

class AddEditChildScreen extends StatefulWidget {
  final ChildModel? initialChild;

  const AddEditChildScreen({super.key, this.initialChild});

  bool get isEditing => initialChild != null;

  @override
  State<AddEditChildScreen> createState() => _AddEditChildScreenState();
}

class _AddEditChildScreenState extends State<AddEditChildScreen> {
  final nameController = TextEditingController();
  final notesController = TextEditingController();
  final schoolController = TextEditingController();
  final gradeController = TextEditingController();
  final activitiesController = TextEditingController();

  DateTime? dob;
  String gender = 'Male';
  bool saving = false;
  bool _photoBusy = false;
  double _photoProgress = 0;

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      final c = widget.initialChild!;
      nameController.text = c.name;
      notesController.text = c.medicalNotes?.trim() ?? '';
      schoolController.text = c.school?.trim() ?? '';
      gradeController.text = c.grade?.trim() ?? '';
      activitiesController.text = c.activities?.trim() ?? '';
      dob = c.dob;
      gender = c.gender;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    notesController.dispose();
    schoolController.dispose();
    gradeController.dispose();
    activitiesController.dispose();
    super.dispose();
  }

  bool get isValid => nameController.text.trim().isNotEmpty && dob != null;

  Future<void> _pickChildPhoto() async {
    if (!widget.isEditing) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Save your child first, then add a private photo from Edit.'),
        ),
      );
      return;
    }
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
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _handleChildPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: PLDesign.primary),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _handleChildPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChildPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop photo',
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop photo'),
        ],
      );
    } on PlatformException catch (e, st) {
      if (kDebugMode) {
        debugPrint('image_cropper failed: $e\n$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the photo editor.')),
      );
      return;
    }

    if (cropped == null || !mounted) return;

    final childId = widget.initialChild!.id;
    setState(() {
      _photoBusy = true;
      _photoProgress = 0;
    });
    try {
      await ChildPrivatePhotoService.uploadPhoto(
        childId: childId,
        file: File(cropped.path),
        onProgress: (p) {
          if (mounted) setState(() => _photoProgress = p);
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Photo saved privately — only you can see it on this device.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _photoBusy = false;
          _photoProgress = 0;
        });
      }
    }
  }

  Future<void> pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dob ?? DateTime(2015),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => dob = picked);
    }
  }

  Future<void> saveChild() async {
    if (!isValid || saving) return;

    final caseId = context.read<CaseContext>().caseId;

    if (caseId == null) return;

    setState(() => saving = true);

    final name = nameController.text.trim();
    final school = schoolController.text.trim();
    final grade = gradeController.text.trim();
    final activities = activitiesController.text.trim();
    final medicalNotes = notesController.text.trim();

    try {
      if (widget.isEditing) {
        await ChildService.updateChild(
          caseId: caseId,
          childId: widget.initialChild!.id,
          name: name,
          dob: dob!,
          gender: gender,
          school: school,
          grade: grade,
          activities: activities,
          medicalNotes: medicalNotes,
        );
      } else {
        await ChildService.createChild(
          caseId: caseId,
          name: name,
          dob: dob!,
          gender: gender,
          medicalNotes: medicalNotes,
          school: school,
          grade: grade,
          activities: activities,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _buildChildPhotoCircle(BuildContext context) {
    final radius = 45.0;
    if (!widget.isEditing) {
      return Container(
        height: radius * 2,
        width: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(Icons.child_care,
            size: radius * 1.1, color: Colors.white.withValues(alpha: 0.45)),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<String>>(
      stream: ChildPrivatePhotoService.watchPhotoUrls(
        uid: user.uid,
        childId: widget.initialChild!.id,
      ),
      builder: (context, snap) {
        final urls = snap.data ?? const <String>[];
        final primary = urls.isNotEmpty ? urls.first : null;

        return GestureDetector(
          onTap: _photoBusy ? null : _pickChildPhoto,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: radius * 2,
                width: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: _photoBusy
                    ? SizedBox(
                        width: radius,
                        height: radius,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          value: _photoProgress > 0 && _photoProgress < 1
                              ? _photoProgress
                              : null,
                          color: const Color(0xff818cf8),
                        ),
                      )
                    : buildChildAvatar(primary, radius: radius),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xff3d7cff),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(decoration: PLDesign.screenGradient),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.isEditing ? 'Edit Child' : 'Add Child',
                    style: PLDesign.pageTitle,
                  ),
                  const SizedBox(height: 30),
                  Center(child: _buildChildPhotoCircle(context)),
                  const SizedBox(height: 12),
                  Text(
                    widget.isEditing
                        ? 'Private to you — not shared with your co-parent automatically.'
                        : 'After saving, you can add a private photo from Edit.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _inputField(
                    controller: nameController,
                    hint: 'Child name',
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: pickDob,
                    child: _glassBox(
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: Colors.white70),
                          const SizedBox(width: 12),
                          Text(
                            dob == null
                                ? 'Date of birth'
                                : '${dob!.month}/${dob!.day}/${dob!.year}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _chip('Male'),
                      const SizedBox(width: 10),
                      _chip('Female'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _inputField(
                    controller: schoolController,
                    hint: 'School (optional)',
                  ),
                  const SizedBox(height: 16),
                  _inputField(
                    controller: gradeController,
                    hint: 'Grade (optional)',
                  ),
                  const SizedBox(height: 16),
                  _inputField(
                    controller: activitiesController,
                    hint: 'Activities (optional, e.g. soccer, piano)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _inputField(
                    controller: notesController,
                    hint: 'Medical notes (optional)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: isValid ? saveChild : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: isValid
                            ? const LinearGradient(
                                colors: [
                                  Color(0xff76c3ff),
                                  Color(0xff3d7cff),
                                ],
                              )
                            : null,
                        color: isValid
                            ? null
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                      child: Center(
                        child: saving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                widget.isEditing ? 'Save Changes' : 'Add Child',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
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

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return _glassBox(
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _glassBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }

  Widget _chip(String value) {
    final selected = gender == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => gender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? const Color(0xff3d7cff)
                : Colors.white.withValues(alpha: 0.06),
          ),
          child: Center(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
