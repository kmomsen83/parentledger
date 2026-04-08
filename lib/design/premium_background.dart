import 'package:flutter/material.dart';

class PremiumBackground extends StatelessWidget {
final Widget child;

const PremiumBackground({super.key, required this.child});

@override
Widget build(BuildContext context) {
return Stack(
children: [

/// ⭐ BASE DEEP BLUE
Container(
decoration: const BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Color(0xff06142b),
Color(0xff0d2d63),
Color(0xff133f87),
],
),
),
),

/// ⭐ SOFT WAVE LIGHT
Positioned.fill(
child: IgnorePointer(
child: Opacity(
opacity: .35,
child: Container(
decoration: const BoxDecoration(
gradient: RadialGradient(
radius: 1.2,
center: Alignment(0, .8),
colors: [
Color(0xff7fc8ff),
Colors.transparent,
],
),
),
),
),
),
),

/// ⭐ FLOATING BLOOM FOG
Positioned.fill(
child: IgnorePointer(
child: Container(
decoration: const BoxDecoration(
gradient: RadialGradient(
radius: 1.6,
center: Alignment(.6, -.3),
colors: [
Color(0x55ffffff),
Colors.transparent,
],
),
),
),
),
),

child,
],
);
}
}
