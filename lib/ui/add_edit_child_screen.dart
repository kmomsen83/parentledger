import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/case_context.dart';
import '../services/child_service.dart';
import '../models/child_model.dart';
import '../design/design.dart';

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
                  Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        height: 90,
                        width: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
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
                          const Icon(Icons.calendar_today, color: Colors.white70),
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
                                widget.isEditing
                                    ? 'Save Changes'
                                    : 'Add Child',
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
