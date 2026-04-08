import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaseContext extends ChangeNotifier {
String? caseId;
List<String> parents = [];
List<dynamic> children = [];

bool loading = true;

StreamSubscription<DocumentSnapshot>? _caseSub;

/// 🔥 INITIAL LOAD
Future<void> bootstrap() async {
final user = FirebaseAuth.instance.currentUser;
if (user == null) return;

final db = FirebaseFirestore.instance;

/// 🔥 CLEAN OLD LISTENER (IMPORTANT)
await _caseSub?.cancel();
_caseSub = null;

loading = true;
notifyListeners();

/// 🔥 GET USER DOC
final userDoc =
await db.collection("users").doc(user.uid).get();

final data = userDoc.data();
if (data == null) {
loading = false;
notifyListeners();
return;
}

caseId = data["caseId"];

/// 🔥 NO CASE YET
if (caseId == null) {
parents = [];
children = [];
loading = false;
notifyListeners();
return;
}

/// 🔥 LISTEN TO CASE (REALTIME)
_caseSub = db
.collection("cases")
.doc(caseId)
.snapshots()
.listen((snap) {
if (!snap.exists) return;

final caseData = snap.data() as Map<String, dynamic>;

parents = List<String>.from(caseData["parents"] ?? []);
children = List.from(caseData["children"] ?? []);

loading = false;
notifyListeners();
});
}

/// 🔥 RESET ON LOGOUT
void reset() {
_caseSub?.cancel();
_caseSub = null;

caseId = null;
parents = [];
children = [];
loading = false;

notifyListeners();
}

/// 🔥 GET COPARENT ID
String? get coparentId {
final user = FirebaseAuth.instance.currentUser;
if (user == null) return null;

try {
return parents.firstWhere((id) => id != user.uid);
} catch (_) {
return null;
}
}

@override
void dispose() {
_caseSub?.cancel();
super.dispose();
}
}
