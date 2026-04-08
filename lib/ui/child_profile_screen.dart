import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../models/child_model.dart';
import '../../providers/case_context.dart';
import '../../services/child_service.dart';
import 'add_edit_child_screen.dart';

class ChildProfileScreen extends StatefulWidget {
final ChildModel child;

const ChildProfileScreen({
super.key,
required this.child,
});

@override
State<ChildProfileScreen> createState() =>
_ChildProfileScreenState();
}

class _ChildProfileScreenState
extends State<ChildProfileScreen> {
bool uploading = false;
String? localImagePath;

int getAge() {
if (widget.child.dob == null) return 0;
final now = DateTime.now();
int age = now.year - widget.child.dob!.year;
if (now.month < widget.child.dob!.month ||
(now.month == widget.child.dob!.month &&
now.day < widget.child.dob!.day)) {
age--;
}
return age;
}

/// 📸 PICK SOURCE
Future<void> pickPhoto() async {
showModalBottomSheet(
context: context,
backgroundColor: Colors.black87,
shape: const RoundedRectangleBorder(
borderRadius:
BorderRadius.vertical(top: Radius.circular(20)),
),
builder: (_) {
return SafeArea(
child: Wrap(
children: [
ListTile(
leading: const Icon(Icons.camera_alt),
title: const Text("Take Photo"),
onTap: () {
Navigator.pop(context);
_handlePick(ImageSource.camera);
},
),
ListTile(
leading: const Icon(Icons.photo),
title:
const Text("Choose from Gallery"),
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
final caseId =
context.read<CaseContext>().caseId;

if (caseId == null) return;

final picker = ImagePicker();
final picked =
await picker.pickImage(source: source);

if (picked == null) return;

setState(() {
uploading = true;
localImagePath = picked.path;
});

final file = File(picked.path);

/// 🔥 STORAGE (STRUCTURED CORRECTLY)
final ref = FirebaseStorage.instance
.ref(
"cases/$caseId/children/${widget.child.id}.jpg");

await ref.putFile(file);

final url = await ref.getDownloadURL();

/// ✅ 🔥 PROPER SERVICE CALL (THIS IS THE FIX)
await ChildService.updateChildPartial(
caseId: caseId,
childId: widget.child.id,
data: {
"photoUrl": url,
},
);

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Photo updated")),
);
} catch (e) {
debugPrint("❌ Upload error: $e");

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Upload failed")),
);
}

if (mounted) {
setState(() => uploading = false);
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
extendBodyBehindAppBar: true,
body: Stack(
children: [
/// 🌄 BACKGROUND
Positioned.fill(
child: Image.asset(
"lib/design/premium_entry_screen_background.png",
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
Colors.black.withOpacity(.35),
Colors.black.withOpacity(.75),
],
),
),
),
),

SafeArea(
child: SingleChildScrollView(
physics:
const BouncingScrollPhysics(),
child: Column(
children: [
/// HEADER
Padding(
padding:
const EdgeInsets.symmetric(
horizontal: 12),
child: Row(
children: [
IconButton(
icon: const Icon(
Icons.arrow_back_ios_new),
onPressed: () =>
Navigator.pop(context),
),
const Spacer(),
const Text(
"Child Profile",
style: TextStyle(
fontSize: 18,
fontWeight:
FontWeight.w800,
),
),
const Spacer(),
IconButton(
icon:
const Icon(Icons.edit),
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
AddEditChildScreen(
initialChild:
widget.child,
),
),
);
},
),
],
),
),

const SizedBox(height: 10),

/// 📸 PHOTO UX (PREMIUM)
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
gradient:
const LinearGradient(
colors: [
Color(0xff76c3ff),
Color(0xff3d7cff),
],
),
boxShadow: [
BoxShadow(
color: Colors.blue
.withOpacity(.4),
blurRadius: 40,
)
],
),
child: ClipOval(
child: localImagePath !=
null
? Image.file(
File(localImagePath!),
fit: BoxFit.cover,
)
: widget.child
.photoUrl !=
null
? Image.network(
widget.child
.photoUrl!,
fit: BoxFit.cover,
)
: Center(
child: Text(
widget.child.name
.substring(
0, 1)
.toUpperCase(),
style:
const TextStyle(
fontSize: 50,
fontWeight:
FontWeight
.w900,
),
),
),
),
),

/// ✏️ EDIT BADGE
Positioned(
bottom: 0,
right: 0,
child: Container(
padding:
const EdgeInsets.all(
6),
decoration: BoxDecoration(
shape: BoxShape.circle,
color: Colors.black87,
border: Border.all(
color:
Colors.white24),
),
child: const Icon(
Icons.edit,
size: 18,
),
),
),

/// ⏳ LOADING
if (uploading)
Positioned.fill(
child: ClipOval(
child: BackdropFilter(
filter: ImageFilter.blur(
sigmaX: 6,
sigmaY: 6),
child: Container(
color:
Colors.black38,
child:
const Center(
child:
CircularProgressIndicator(),
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
widget.child.name,
style: const TextStyle(
fontSize: 34,
fontWeight: FontWeight.w900,
),
),

if (widget.child.dob != null)
Text(
"Age ${getAge()}",
style: const TextStyle(
color: Colors.white70,
fontSize: 15,
),
),

const SizedBox(height: 26),

_InfoCard(
title: "School",
value:
widget.child.school ??
"Not added",
),
_InfoCard(
title: "Grade",
value:
widget.child.grade ??
"Not added",
),
_InfoCard(
title: "Activities",
value: widget.child
.activities ??
"Not added",
),
_InfoCard(
title: "Medical Notes",
value: widget.child
.medicalNotes ??
"None",
),

const SizedBox(height: 120),
],
),
),
),
],
),
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
borderRadius:
BorderRadius.circular(22),
child: BackdropFilter(
filter: ImageFilter.blur(
sigmaX: 14, sigmaY: 14),
child: Container(
margin:
const EdgeInsets.symmetric(
horizontal: 20,
vertical: 8),
padding:
const EdgeInsets.all(20),
decoration: BoxDecoration(
color:
Colors.white.withOpacity(.08),
borderRadius:
BorderRadius.circular(22),
border: Border.all(
color: Colors.white
.withOpacity(.14),
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
Text(
value,
style: const TextStyle(
fontWeight:
FontWeight.w700,
),
),
],
),
),
),
);
}
}
