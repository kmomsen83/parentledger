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
BoxShadow(
color: Colors.blueAccent.withValues(alpha:.25),
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
color: Colors.white.withValues(alpha:.10),
borderRadius: BorderRadius.circular(22),
border: Border.all(
color: Colors.white.withValues(alpha:.25),
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
