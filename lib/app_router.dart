import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ui/entry_screen.dart';
import 'ui/signup_screen.dart';
import 'ui/subscription_screen.dart';
import 'ui/workspace_coparent_setup_screen.dart';
import 'ui/children_list_screen.dart';
import 'ui/dashboard_screen.dart';
import 'ui/accept_invite_screen.dart';

import 'services/invite_service.dart';

class AppRouter extends StatefulWidget {
final String? inviteId; // 🔥 NEW

const AppRouter({super.key, this.inviteId});

@override
State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
String? lastInviteCheckedUserId;
String? pendingInviteId;

@override
void initState() {
super.initState();

/// 🔥 CAPTURE INVITE ON APP START
pendingInviteId = widget.inviteId;
}

/// 🔥 RUN INVITE ONCE (NON-BLOCKING)
Future<void> runInviteCheck(User user) async {
if (lastInviteCheckedUserId == user.uid) return;

lastInviteCheckedUserId = user.uid;

try {
await InviteService.checkAndAcceptInvite(user);
} catch (_) {
// never block UI
}
}

/// 🔥 ENSURE USER DOC EXISTS
Future<void> ensureUserDoc(User user) async {
final ref =
FirebaseFirestore.instance.collection("users").doc(user.uid);

final doc = await ref.get();

if (!doc.exists) {
await ref.set({
"createdAt": FieldValue.serverTimestamp(),
"onboardingStep": "new",
"isPremium": false,
});
}
}

@override
Widget build(BuildContext context) {
return StreamBuilder<User?>(
stream: FirebaseAuth.instance.authStateChanges(),
builder: (context, authSnap) {

/// 🔥 AUTH LOADING
if (authSnap.connectionState == ConnectionState.waiting) {
return const _LoadingGate();
}

final user = authSnap.data;

/// 🔒 NOT LOGGED IN
if (user == null) {
return EntryScreen(inviteId: pendingInviteId);
}

/// 🔥 SAFE SIDE EFFECTS
WidgetsBinding.instance.addPostFrameCallback((_) {
ensureUserDoc(user);
runInviteCheck(user);
});

/// 🔥 REALTIME USER DOC
return StreamBuilder<DocumentSnapshot>(
stream: FirebaseFirestore.instance
.collection("users")
.doc(user.uid)
.snapshots(),
builder: (context, snap) {

/// 🔥 USER DOC LOADING
if (!snap.hasData) {
return const _LoadingGate();
}

final data =
snap.data!.data() as Map<String, dynamic>? ?? {};

final step = data["onboardingStep"] ?? "new";

/// ====================================
/// 🔥 INVITE TAKES PRIORITY (CRITICAL)
/// ====================================
if (pendingInviteId != null) {
final inviteId = pendingInviteId!;
pendingInviteId = null; // prevent loops

return AcceptInviteScreen(inviteId: inviteId);
}

/// ====================================
/// 🔥 NORMAL FLOW
/// ====================================
switch (step) {

case "new":
return const SignupScreen();

case "profile_complete":
return const WorkspaceCoparentSetupScreen();

case "coparent_invited":
return const ChildrenListScreen();

case "children_added":
return const SubscriptionScreen();

case "subscribed":
return const DashboardScreen();

default:
return const SignupScreen();
}
},
);
},
);
}
}

/// 🔥 CLEAN LOADING
class _LoadingGate extends StatelessWidget {
const _LoadingGate();

@override
Widget build(BuildContext context) {
return const Scaffold(
backgroundColor: Colors.black,
body: Center(
child: CircularProgressIndicator(
color: Colors.white,
),
),
);
}
}
