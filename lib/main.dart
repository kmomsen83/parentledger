import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:purchases_flutter/purchases_flutter.dart';

import 'ui/splash_screen.dart';
import 'firebase_options.dart';
import 'providers/case_context.dart';
import 'design/design.dart';

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();

/// 🔥 FIREBASE INIT
await Firebase.initializeApp(
options: DefaultFirebaseOptions.currentPlatform,
);

/// 🔒 APP CHECK
await FirebaseAppCheck.instance.activate(
androidProvider: AndroidProvider.debug,
);

/// 💰 REVENUECAT INIT
await Purchases.setLogLevel(LogLevel.debug);

final configuration = PurchasesConfiguration(
"", // 🔥 replace this
);

await Purchases.configure(configuration);

runApp(const AppBootstrap());
}

/// 🔥 PROVIDERS
class AppBootstrap extends StatelessWidget {
const AppBootstrap({super.key});

@override
Widget build(BuildContext context) {
return MultiProvider(
providers: [
ChangeNotifierProvider(create: (_) => CaseContext()),
],
child: const _AuthSync(),
);
}
}

/// 🔥 AUTH SYNC (NOW INCLUDES REVENUECAT LOGIN)
class _AuthSync extends StatefulWidget {
const _AuthSync();

@override
State<_AuthSync> createState() => _AuthSyncState();
}

class _AuthSyncState extends State<_AuthSync> {
String? lastUserId;

@override
Widget build(BuildContext context) {
final caseContext = context.read<CaseContext>();

return StreamBuilder<User?>(
stream: FirebaseAuth.instance.authStateChanges(),
builder: (context, snap) {
if (snap.connectionState == ConnectionState.waiting) {
return const _BootLoading();
}

final user = snap.data;

/// 🔥 SYNC USER + REVENUECAT
if (user?.uid != lastUserId) {
lastUserId = user?.uid;

WidgetsBinding.instance.addPostFrameCallback((_) async {
if (user != null) {
/// 🔑 LOGIN TO REVENUECAT
await Purchases.logIn(user.uid);

caseContext.bootstrap();
} else {
/// 🔑 LOGOUT FROM REVENUECAT
await Purchases.logOut();

caseContext.reset();
}
});
}

return const ParentLedgerApp();
},
);
}
}

/// 🔥 LOADING SCREEN
class _BootLoading extends StatelessWidget {
const _BootLoading();

@override
Widget build(BuildContext context) {
return const Material(
color: Colors.black,
child: Center(
child: CircularProgressIndicator(),
),
);
}
}

/// 🎯 MAIN APP
class ParentLedgerApp extends StatelessWidget {
const ParentLedgerApp({super.key});

@override
Widget build(BuildContext context) {
return MaterialApp(
debugShowCheckedModeBanner: false,
title: "ParentLedger",
theme: appTheme,

/// 🔥 ENTRY POINT
home: const SplashScreen(),

builder: (context, child) {
return MediaQuery(
data: MediaQuery.of(context).copyWith(
textScaler: const TextScaler.linear(1.0),
),
child: child!,
);
},
);
}
}
