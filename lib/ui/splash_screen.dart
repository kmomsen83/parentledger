import 'package:flutter/material.dart';
import 'dart:async';

import '../app_router.dart'; // 🔥 IMPORTANT

class SplashScreen extends StatefulWidget {
const SplashScreen({super.key});

@override
State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
with TickerProviderStateMixin {

late AnimationController textController;
late AnimationController transitionController;

late Animation<double> textFade;
late Animation<double> screenFade;

@override
void initState() {
super.initState();

/// 🔥 PREMIUM TEXT FADE
textController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 4500),
);

textFade = CurvedAnimation(
parent: textController,
curve: Curves.easeInOut,
);

/// 🔥 SCREEN CROSSFADE
transitionController = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 900),
);

screenFade = Tween<double>(begin: 1, end: 0).animate(
CurvedAnimation(
parent: transitionController,
curve: Curves.easeInOut,
),
);

runSequence();
}

Future<void> runSequence() async {
/// 1. fade in tagline
await textController.forward();

/// 2. slight pause
await Future.delayed(const Duration(milliseconds: 500));

/// 3. fade out splash
await transitionController.forward();

/// 4. HAND OFF TO ROUTER (CRITICAL FIX)
if (!mounted) return;

Navigator.pushReplacement(
context,
PageRouteBuilder(
pageBuilder: (_, __, ___) => const AppRouter(),
transitionDuration: const Duration(milliseconds: 500),
transitionsBuilder: (_, animation, __, child) {
return FadeTransition(
opacity: animation,
child: child,
);
},
),
);
}

@override
void dispose() {
textController.dispose();
transitionController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return FadeTransition(
opacity: screenFade,
child: Scaffold(
body: Stack(
fit: StackFit.expand,
children: [

/// 🔥 BACKGROUND
Image.asset(
"lib/design/splash_screen_background.png",
fit: BoxFit.cover,
),

/// 🔥 CONTENT
Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [

/// 🔥 TITLE
const Text(
"ParentLedger",
style: TextStyle(
fontSize: 36,
fontWeight: FontWeight.w800,
color: Colors.white,
letterSpacing: 0.5,
shadows: [
Shadow(
color: Colors.black54,
blurRadius: 18,
),
],
),
),

const SizedBox(height: 12),

/// 🔥 TAGLINE (ANIMATED)
FadeTransition(
opacity: textFade,
child: const Text(
"Custody. Clarity. Peace.",
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w500,
color: Colors.white,
letterSpacing: 0.6,
shadows: [
Shadow(
color: Colors.black87,
blurRadius: 20,
),
],
),
),
),
],
),
),
],
),
),
);
}
}
