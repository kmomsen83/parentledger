import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../design/design.dart';

class ChildrenListScreen extends StatefulWidget {
const ChildrenListScreen({super.key});

@override
State<ChildrenListScreen> createState() => _ChildrenListScreenState();
}

class _ChildrenListScreenState extends State<ChildrenListScreen> {
final nameController = TextEditingController();
final ageController = TextEditingController();

bool loading = false;
String? caseId;

@override
void initState() {
super.initState();
_loadCase();
}

Future<void> _loadCase() async {
final user = FirebaseAuth.instance.currentUser;
if (user == null) return;

final doc = await FirebaseFirestore.instance
.collection("users")
.doc(user.uid)
.get();

setState(() {
caseId = doc.data()?["caseId"];
});
}

void _error(String msg) {
ScaffoldMessenger.of(context)
.showSnackBar(SnackBar(content: Text(msg)));
}

/// ================================
/// 🔥 ADD CHILD
/// ================================
Future<void> addChild() async {
if (loading) return;

final user = FirebaseAuth.instance.currentUser;

if (user == null || caseId == null) {
_error("Missing case");
return;
}

final name = nameController.text.trim();
final age = ageController.text.trim();

if (name.isEmpty || age.isEmpty) {
_error("Enter name and age");
return;
}

setState(() => loading = true);

try {
await FirebaseFirestore.instance
.collection("cases")
.doc(caseId)
.collection("children")
.add({
"name": name,
"age": int.tryParse(age) ?? 0,
"createdAt": FieldValue.serverTimestamp(),
});

nameController.clear();
ageController.clear();

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text("Child added")),
);

} catch (e) {
print("❌ ADD CHILD ERROR: $e");
_error("Failed to add child");
}

if (mounted) setState(() => loading = false);
}

/// ================================
/// 🔥 CONTINUE
/// ================================
Future<void> continueFlow() async {
final user = FirebaseAuth.instance.currentUser;
if (user == null || caseId == null) return;

final snapshot = await FirebaseFirestore.instance
.collection("cases")
.doc(caseId)
.collection("children")
.get();

if (snapshot.docs.isEmpty) {
_error("Add at least one child");
return;
}

await FirebaseFirestore.instance
.collection("users")
.doc(user.uid)
.update({
"onboardingStep": "children_added",
});
}

/// ================================
/// UI
/// ================================
@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.transparent,
body: Stack(
fit: StackFit.expand,
children: [

/// BACKGROUND
Container(decoration: PLDesign.screenGradient),

SafeArea(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
children: [

const SizedBox(height: 20),

const Text(
"Your Children",
style: PLDesign.pageTitle,
),

const SizedBox(height: 6),

const Text(
"Add all children before continuing",
style: PLDesign.body,
),

const SizedBox(height: 30),

/// INPUT CARD
Container(
padding: const EdgeInsets.all(16),
decoration: PLDesign.elevatedCard,
child: Column(
children: [

_input(
"Child name",
nameController,
capitalize: true,
),

const SizedBox(height: 12),

_input(
"Age",
ageController,
type: TextInputType.number,
),

const SizedBox(height: 16),

GestureDetector(
onTap: loading ? null : addChild,
child: Container(
height: 50,
decoration: BoxDecoration(
gradient: PLDesign.primaryGradient,
borderRadius: BorderRadius.circular(14),
),
child: Center(
child: loading
? const CircularProgressIndicator(color: Colors.white)
: const Text(
"Add Child",
style: PLDesign.buttonText,
),
),
),
),
],
),
),

const SizedBox(height: 24),

/// 🔥 LIVE CHILD LIST
if (caseId != null)
Expanded(
child: StreamBuilder<QuerySnapshot>(
stream: FirebaseFirestore.instance
.collection("cases")
.doc(caseId)
.collection("children")
.orderBy("createdAt", descending: true)
.snapshots(),
builder: (context, snap) {

if (!snap.hasData) {
return const Center(
child: CircularProgressIndicator(),
);
}

final docs = snap.data!.docs;

if (docs.isEmpty) {
return const Center(
child: Text(
"No children added yet",
style: TextStyle(color: Colors.white54),
),
);
}

return ListView.builder(
itemCount: docs.length,
itemBuilder: (context, i) {
final data =
docs[i].data() as Map<String, dynamic>;

return Container(
margin: const EdgeInsets.only(bottom: 12),
padding: const EdgeInsets.all(14),
decoration: PLDesign.elevatedCard,
child: Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
Text(
data["name"] ?? "",
style: const TextStyle(
color: Colors.white,
fontSize: 16),
),
Text(
"Age ${data["age"]}",
style: const TextStyle(
color: Colors.white70),
),
],
),
);
},
);
},
),
),

const SizedBox(height: 12),

/// CONTINUE BUTTON
GestureDetector(
onTap: continueFlow,
child: Container(
height: 56,
decoration: BoxDecoration(
gradient: PLDesign.primaryGradient,
borderRadius: BorderRadius.circular(20),
),
child: const Center(
child: Text(
"Continue to Subscription",
style: PLDesign.buttonText,
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

/// INPUT
Widget _input(
String hint,
TextEditingController controller, {
TextInputType type = TextInputType.text,
bool capitalize = false,
}) {
return Container(
padding: const EdgeInsets.symmetric(horizontal: 16),
height: 54,
decoration: BoxDecoration(
color: PLDesign.surface,
borderRadius: BorderRadius.circular(14),
border: Border.all(color: PLDesign.border),
),
child: Center(
child: TextField(
controller: controller,
keyboardType: type,
textCapitalization:
capitalize ? TextCapitalization.words : TextCapitalization.none,
style: const TextStyle(color: Colors.white),
decoration: InputDecoration(
hintText: hint,
hintStyle: const TextStyle(color: Colors.white54),
border: InputBorder.none,
),
),
),
);
}
}
