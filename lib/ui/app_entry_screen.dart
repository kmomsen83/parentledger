import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'workspace_coparent_setup_screen.dart';
import 'add_edit_child_screen.dart';
import 'dashboard_screen.dart';

class AppEntryScreen extends StatelessWidget {
const AppEntryScreen({super.key});

String get uid => FirebaseAuth.instance.currentUser!.uid;

Future<Map<String, dynamic>> getUserData() async {
final doc = await FirebaseFirestore.instance
.collection("users")
.doc(uid)
.get();

final data = doc.data() ?? <String, dynamic>{};
return <String, dynamic>{
  '_exists': doc.exists,
  ...data,
};
}

@override
Widget build(BuildContext context) {
return FutureBuilder(
future: getUserData(),
builder: (context, snapshot) {

if (!snapshot.hasData) {
return const Scaffold(
body: Center(child: CircularProgressIndicator()),
);
}

final data = snapshot.data as Map<String, dynamic>;
final userDocExists = data['_exists'] == true;

final hasCoParent = data["hasCoParent"] ?? false;
final hasChild = data["hasChild"] ?? false;

/// 🚨 ROUTING LOGIC
if (!userDocExists) {
return const WorkspaceCoparentSetupScreen();
}

if (!hasCoParent) {
return const WorkspaceCoparentSetupScreen();
}

if (!hasChild) {
return const AddEditChildScreen();
}

return const DashboardScreen();
},
);
}
}
