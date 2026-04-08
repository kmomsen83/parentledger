import 'dart:ui';
import 'package:flutter/material.dart';

class GlassIconCard extends StatelessWidget {
final IconData icon;

const GlassIconCard({super.key, required this.icon});

@override
Widget build(BuildContext context) {
return Container(
width: 82,
height: 82,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(22),
boxShadow: [

/// ⭐ OUTER BLUE GLOW
BoxShadow(
color: Colors.blueAccent.withOpacity(.25),
blurRadius: 30,
spreadRadius: 1,
),
],
),
child: ClipRRect(
borderRadius: BorderRadius.circular(22),
child: BackdropFilter(
filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
child: Container(
decoration: BoxDecoration(
color: Colors.white.withOpacity(.10),
borderRadius: BorderRadius.circular(22),
border: Border.all(
color: Colors.white.withOpacity(.25),
width: 1.2,
),
),
child: Icon(
icon,
color: Colors.white,
size: 30,
),
),
),
),
);
}
}
