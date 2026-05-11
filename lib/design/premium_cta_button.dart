import 'package:flutter/material.dart';

class PremiumCTA extends StatelessWidget {
final String text;
final VoidCallback onTap;

const PremiumCTA({super.key, required this.text, required this.onTap});

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: onTap,
child: Container(
height: 64,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(26),
gradient: const LinearGradient(
colors: [
Color(0xff7fd1ff),
Color(0xff4fa3ff),
Color(0xff2f7cff),
],
),
boxShadow: [

/// ⭐ HUGE PREMIUM GLOW
BoxShadow(
color: const Color(0xff5ea9ff).withValues(alpha: .65),
blurRadius: 55,
spreadRadius: 4,
offset: const Offset(0, 20),
),

/// ⭐ SOFT INNER SHADOW
const BoxShadow(
color: Colors.black26,
blurRadius: 18,
offset: Offset(0, 6),
)
],
),
child: Center(
child: Text(
text,
style: const TextStyle(
fontSize: 19,
fontWeight: FontWeight.w700,
letterSpacing: .2,
color: Colors.white,
),
),
),
),
);
}
}
