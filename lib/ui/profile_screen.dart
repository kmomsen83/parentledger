import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../ui/children_list_screen.dart';
import '../ui/subscription_screen.dart';
import '../ui/entry_screen.dart';
import '../../design/design.dart';

class ProfileScreen extends StatefulWidget {
const ProfileScreen({super.key});

@override
State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
double uploadProgress = 0;
bool uploading = false;

/// ================================
/// 📸 PICK PHOTO
/// ================================
Future<void> pickPhoto(BuildContext context) async {
showModalBottomSheet(
context: context,
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
title: const Text("Choose from Gallery"),
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

Future<void> _handlePick(ImageSource source) async {
final picked = await ImagePicker().pickImage(source: source);
if (picked == null) return;

final cropped = await ImageCropper().cropImage(
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

if (cropped == null) return;

await _uploadPhoto(File(cropped.path));
}

Future<void> _uploadPhoto(File file) async {
final uid = FirebaseAuth.instance.currentUser!.uid;

try {
setState(() {
uploading = true;
uploadProgress = 0;
});

final ref =
FirebaseStorage.instance.ref("profile_photos/$uid.jpg");

final task = ref.putFile(file);

task.snapshotEvents.listen((e) {
setState(() {
uploadProgress =
e.bytesTransferred / e.totalBytes;
});
});

await task;

final url = await ref.getDownloadURL();

await FirebaseFirestore.instance
.collection("users")
.doc(uid)
.update({"photoUrl": url});

if (!mounted) return;

setState(() => uploading = false);

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Profile updated")),
);
} catch (e) {
setState(() => uploading = false);

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Upload failed")),
);
}
}

/// ================================
/// 🔥 LOAD USER
/// ================================
Future<Map<String, dynamic>> _loadUser() async {
final uid = FirebaseAuth.instance.currentUser!.uid;

final doc = await FirebaseFirestore.instance
.collection("users")
.doc(uid)
.get();

return doc.data() ?? {};
}

/// ================================
/// 🔥 COPARENT STATUS
/// ================================
Future<Map<String, dynamic>> _getCoparentStatus() async {
final uid = FirebaseAuth.instance.currentUser!.uid;
final db = FirebaseFirestore.instance;

final userDoc = await db.collection("users").doc(uid).get();
final caseId = userDoc.data()?["caseId"];

if (caseId == null) return {"status": "none"};

final members = await db
.collection("cases")
.doc(caseId)
.collection("members")
.get();

final others =
members.docs.where((d) => d.id != uid).toList();

if (others.isNotEmpty) {
return {
"status": "connected",
"name": others.first.data()["name"] ?? "Co-Parent"
};
}

final invites = await db
.collection("caseInvites")
.where("fromUserId", isEqualTo: uid)
.where("caseId", isEqualTo: caseId)
.where("status", isEqualTo: "pending")
.limit(1)
.get();

if (invites.docs.isNotEmpty) {
return {"status": "pending"};
}

return {"status": "none"};
}

/// ================================
/// 🔥 LAST ACTIVITY
/// ================================
Future<String> _getLastActivity() async {
final uid = FirebaseAuth.instance.currentUser!.uid;

final logs = await FirebaseFirestore.instance
.collection("activityLogs")
.where("userId", isEqualTo: uid)
.orderBy("createdAt", descending: true)
.limit(1)
.get();

if (logs.docs.isEmpty) return "No recent activity";

final data = logs.docs.first.data();
final type = data["type"] ?? "Activity";

return "Last action: $type";
}

/// ================================
/// 📩 INVITE MODAL
/// ================================
void showInviteModal(BuildContext context, String role) {
final phoneController = TextEditingController();
final emailController = TextEditingController();

bool sending = false;

showModalBottomSheet(
context: context,
backgroundColor: Colors.transparent,
isScrollControlled: true,
builder: (_) {
return StatefulBuilder(
builder: (context, setState) {
return Container(
padding: EdgeInsets.only(
left: 22,
right: 22,
top: 26,
bottom:
MediaQuery.of(context).viewInsets.bottom + 28,
),
decoration: const BoxDecoration(
color: PLDesign.card,
borderRadius:
BorderRadius.vertical(top: Radius.circular(30)),
),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment:
CrossAxisAlignment.start,
children: [

Text(
role == "coparent"
? "Invite Co-Parent"
: "Invite Third Party",
style: PLDesign.pageTitle,
),

const SizedBox(height: 20),

TextField(
controller: phoneController,
decoration:
const InputDecoration(hintText: "Phone"),
),

const SizedBox(height: 12),

TextField(
controller: emailController,
decoration:
const InputDecoration(hintText: "Email"),
),

const SizedBox(height: 20),

SizedBox(
width: double.infinity,
height: 54,
child: ElevatedButton(
onPressed: sending
? null
: () async {
setState(() => sending = true);

try {
final uid =
FirebaseAuth.instance.currentUser!.uid;

final db =
FirebaseFirestore.instance;

final userDoc = await db
.collection("users")
.doc(uid)
.get();

final caseId =
userDoc.data()?["caseId"];

final inviteRef =
db.collection("caseInvites").doc();

await inviteRef.set({
"inviteId": inviteRef.id,
"fromUserId": uid,
"caseId": caseId,
"toPhone":
phoneController.text.trim(),
"email":
emailController.text.trim(),
"role": role,
"status": "pending",
"createdAt":
FieldValue.serverTimestamp(),
});

Navigator.pop(context);

ScaffoldMessenger.of(context)
.showSnackBar(
const SnackBar(
content: Text("Invite Sent")),
);
} catch (e) {}

if (context.mounted) {
setState(() => sending = false);
}
},
child: sending
? const CircularProgressIndicator()
: const Text("Send Invite"),
),
),
],
),
);
},
);
},
);
}

/// ================================
/// 🧱 OPTION CARD
/// ================================
Widget optionCard(
IconData icon,
String title,
String sub,
VoidCallback tap,
) {
return GestureDetector(
onTap: tap,
child: Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: PLDesign.card,
borderRadius: PLDesign.r20,
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: Row(
children: [
Icon(icon,
color: PLDesign.primary, size: 26),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(title,
style: PLDesign.sectionTitle),
const SizedBox(height: 4),
Text(sub, style: PLDesign.caption),
],
),
),
const Icon(Icons.chevron_right,
color: Colors.white38),
],
),
),
);
}

/// ================================
/// 🧱 COPARENT CARD
/// ================================
Widget coparentCard(BuildContext context) {
return FutureBuilder<Map<String, dynamic>>(
future: _getCoparentStatus(),
builder: (context, snap) {
if (!snap.hasData) return const SizedBox();

final status = snap.data!["status"];

if (status == "connected") {
return optionCard(
Icons.verified,
"Co-Parent Connected",
snap.data!["name"],
() {},
);
}

if (status == "pending") {
return optionCard(
Icons.schedule,
"Invite Sent",
"Tap to resend",
() => showInviteModal(context, "coparent"),
);
}

return optionCard(
Icons.link_off,
"No Co-Parent Connected",
"Tap to invite",
() => showInviteModal(context, "coparent"),
);
},
);
}

/// ================================
/// 🧱 LAST ACTIVITY CARD
/// ================================
Widget lastActivityCard() {
return FutureBuilder<String>(
future: _getLastActivity(),
builder: (context, snap) {
if (!snap.hasData) return const SizedBox();

return optionCard(
Icons.history,
"Recent Activity",
snap.data!,
() {},
);
},
);
}

/// ================================
/// 🔐 LOGOUT
/// ================================
Future<void> logout(BuildContext context) async {
await FirebaseAuth.instance.signOut();

Navigator.pushAndRemoveUntil(
context,
MaterialPageRoute(builder: (_) => const EntryScreen()),
(_) => false,
);
}

/// ================================
/// 🧱 BUILD
/// ================================
@override
Widget build(BuildContext context) {
return Scaffold(
body: Stack(
children: [

Positioned.fill(
child: Image.asset(
"lib/design/premium_entry_screen_background.png",
fit: BoxFit.cover,
),
),

Positioned.fill(
child: Container(
color: Colors.black.withOpacity(.45),
),
),

SafeArea(
child: FutureBuilder<Map<String, dynamic>>(
future: _loadUser(),
builder: (context, snap) {

if (!snap.hasData) {
return const Center(
child: CircularProgressIndicator());
}

final d = snap.data!;

final firstName = d["firstName"] ?? "";
final lastName = d["lastName"] ?? "";
final role = d["role"] ?? "";
final photoUrl = d["photoUrl"];

final fullName =
"$firstName $lastName".trim().isEmpty
? "Parent"
: "$firstName $lastName";

return ListView(
padding:
const EdgeInsets.fromLTRB(22, 20, 22, 40),
children: [

/// HERO
Container(
padding: const EdgeInsets.all(26),
decoration: PLDesign.gradientCard,
child: Column(
children: [

Stack(
alignment: Alignment.center,
children: [
GestureDetector(
onTap: () => pickPhoto(context),
child: CircleAvatar(
radius: 40,
backgroundImage:
photoUrl != null
? NetworkImage(photoUrl)
: null,
child: photoUrl == null
? Text(fullName[0])
: null,
),
),

Positioned(
bottom: 0,
right: 0,
child: Container(
padding:
const EdgeInsets.all(6),
decoration: const BoxDecoration(
color: PLDesign.primary,
shape: BoxShape.circle,
),
child: const Icon(
Icons.camera_alt,
size: 14,
color: Colors.white,
),
),
),

if (uploading)
Container(
width: 80,
height: 80,
decoration: const BoxDecoration(
color: Colors.black54,
shape: BoxShape.circle,
),
child: Center(
child:
CircularProgressIndicator(
value: uploadProgress,
),
),
),
],
),

const SizedBox(height: 12),
Text("Hi $firstName 👋"),
Text(fullName,
style: PLDesign.heroTitle),
Text(role,
style: PLDesign.caption),
],
),
),

const SizedBox(height: 22),

/// 🔥 NEW
coparentCard(context),

const SizedBox(height: 14),

/// 🔥 NEW
lastActivityCard(),

const SizedBox(height: 14),

optionCard(
Icons.child_care,
"Children",
"Profiles & custody context",
() => Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
const ChildrenListScreen(),
),
),
),

const SizedBox(height: 14),

optionCard(
Icons.person_add,
"Invite Co-Parent",
"Send connection invite",
() => showInviteModal(context, "coparent"),
),

const SizedBox(height: 14),

optionCard(
Icons.group_add,
"Invite Third Party",
"Attorney / Therapist / Guardian",
() => showInviteModal(context, "third_party"),
),

const SizedBox(height: 14),

optionCard(
Icons.workspace_premium,
"Manage Subscription",
"Billing, plan, and upgrades",
() => Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
const SubscriptionScreen(),
),
),
),

const SizedBox(height: 14),

optionCard(
Icons.logout,
"Sign Out",
"Securely exit ParentLedger",
() => logout(context),
),
],
);
},
),
),
],
),
);
}
}
