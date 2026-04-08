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

DateTime? dob;
String gender = "Male";
bool saving = false;

@override
void initState() {
super.initState();

if (widget.isEditing) {
final c = widget.initialChild!;
nameController.text = c.name;
notesController.text = c.medicalNotes ?? "";
dob = c.dob;
gender = c.gender;
}
}

bool get isValid {
return nameController.text.trim().isNotEmpty && dob != null;
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

final caseId =
context.read<CaseContext>().caseId;

if (caseId == null) return;

setState(() => saving = true);

if (widget.isEditing) {
await ChildService.updateChild(
caseId: caseId,
childId: widget.initialChild!.id,
name: nameController.text.trim(),
dob: dob!,
gender: gender,
medicalNotes: notesController.text.trim(),
);
} else {
await ChildService.createChild(
caseId: caseId,
name: nameController.text.trim(),
dob: dob!,
gender: gender,
medicalNotes: notesController.text.trim(),
);
}

if (!mounted) return;
Navigator.pop(context);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.transparent,
body: Stack(
children: [
/// 🔥 BACKGROUND
Container(decoration: PLDesign.screenGradient),

SafeArea(
child: SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

/// 🔙 BACK
IconButton(
onPressed: () => Navigator.pop(context),
icon: const Icon(Icons.arrow_back, color: Colors.white),
),

const SizedBox(height: 10),

/// TITLE
Text(
widget.isEditing
? "Edit Child"
: "Add Child",
style: PLDesign.pageTitle,
),

const SizedBox(height: 30),

/// 🧠 AVATAR (NEXT LEVEL FEEL)
Center(
child: GestureDetector(
onTap: () {
// 🔥 NEXT: wire image picker
},
child: Container(
height: 90,
width: 90,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: Colors.white.withOpacity(.08),
border: Border.all(
color: Colors.white.withOpacity(.2),
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

/// NAME
_inputField(
controller: nameController,
hint: "Child name",
),

const SizedBox(height: 16),

/// DOB (PREMIUM PICKER)
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
? "Date of birth"
: "${dob!.month}/${dob!.day}/${dob!.year}",
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

/// GENDER
Row(
children: [
_chip("Male"),
const SizedBox(width: 10),
_chip("Female"),
],
),

const SizedBox(height: 16),

/// NOTES
_inputField(
controller: notesController,
hint: "Medical notes (optional)",
maxLines: 3,
),

const SizedBox(height: 40),

/// 🚀 CTA
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
: Colors.white.withOpacity(.08),
),
child: Center(
child: saving
? const CircularProgressIndicator(
color: Colors.white,
)
: Text(
widget.isEditing
? "Save Changes"
: "Add Child",
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

/// 🔥 GLASS INPUT
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

/// 🔥 GLASS CONTAINER
Widget _glassBox({required Widget child}) {
return Container(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
decoration: BoxDecoration(
color: Colors.white.withOpacity(.06),
borderRadius: BorderRadius.circular(16),
border: Border.all(
color: Colors.white.withOpacity(.1),
),
),
child: child,
);
}

/// 🔥 GENDER CHIP
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
: Colors.white.withOpacity(.06),
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
