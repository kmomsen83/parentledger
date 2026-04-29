import 'package:flutter/material.dart';

import '../design/design.dart';
import 'package:parentledger/ui/ai_fairness_suggestion_screen.dart';

class AiInsightsQuickViewScreen extends StatefulWidget {
const AiInsightsQuickViewScreen({super.key});

@override
State<AiInsightsQuickViewScreen> createState() =>
_AiInsightsQuickViewScreenState();
}

class _AiInsightsQuickViewScreenState
extends State<AiInsightsQuickViewScreen>
with TickerProviderStateMixin {

/// ================================
/// 🔥 PRESS EFFECT
/// ================================
Widget pressable({required Widget child, required VoidCallback onTap}) {
return GestureDetector(
onTap: onTap,
child: AnimatedScale(
scale: 1,
duration: const Duration(milliseconds: 120),
child: child,
),
);
}

/// ================================
/// ⭐ HERO CARD (NEW)
/// ================================
Widget heroCard() {
return Container(
padding: const EdgeInsets.all(26),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(26),
gradient: const LinearGradient(
colors: [
Color(0xff4f46e5),
Color(0xff1d4ed8),
],
),
boxShadow: [
BoxShadow(
color: const Color(0xff4f46e5).withValues(alpha: .35),
blurRadius: 30,
offset: const Offset(0, 18),
),
],
),
child: const Column(
children: [
Text(
"Overall Co-Parent Health",
style: TextStyle(
color: Colors.white70,
fontWeight: FontWeight.w600,
),
),
SizedBox(height: 10),
Text(
"Good Standing",
style: TextStyle(
fontSize: 26,
fontWeight: FontWeight.w900,
color: Colors.white,
),
),
],
),
);
}

/// ================================
/// ⭐ QUICK CARD (UPGRADED)
/// ================================
Widget quickCard({
required IconData icon,
required String title,
required String value,
required Color color,
}) {
return pressable(
onTap: () {},
child: Container(
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(22),
color: PLDesign.card,
border: Border.all(color: PLDesign.border),
boxShadow: PLDesign.softShadow,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

Container(
height: 44,
width: 44,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(14),
gradient: LinearGradient(
colors: [
color.withValues(alpha: .25),
color.withValues(alpha: .10),
],
),
),
child: Icon(icon, color: color),
),

const SizedBox(height: 18),

Text(
title,
style: const TextStyle(
color: Colors.white70,
fontWeight: FontWeight.w600,
),
),

const SizedBox(height: 6),

Text(
value,
style: const TextStyle(
fontSize: 22,
fontWeight: FontWeight.w900,
color: Colors.white,
),
),
],
),
),
);
}

/// ================================
/// ⭐ ALERT TILE (UPGRADED)
/// ================================
Widget alertTile({
required String title,
required String subtitle,
required Color color,
}) {
return pressable(
onTap: () {},
child: Container(
margin: const EdgeInsets.only(bottom: 14),
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(18),
color: PLDesign.card,
border: Border.all(color: color.withValues(alpha: 0.45)),
),
child: Row(
children: [

Container(
height: 10,
width: 10,
decoration: BoxDecoration(
color: color,
shape: BoxShape.circle,
),
),

const SizedBox(width: 12),

Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
title,
style: const TextStyle(
fontWeight: FontWeight.w800,
color: Colors.white,
),
),
const SizedBox(height: 4),
Text(
subtitle,
style: const TextStyle(
color: Colors.white70,
height: 1.3,
),
),
],
),
),

const Icon(Icons.chevron_right,
color: Colors.white54),
],
),
),
);
}

/// ================================
/// BUILD
/// ================================
@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: PLDesign.background,

appBar: AppBar(
backgroundColor: PLDesign.surface,
title: const Text(
"AI Insights",
),
),

body: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
child: Column(
children: [

heroCard(),

const SizedBox(height: 22),
Align(
alignment: Alignment.centerLeft,
child: Text(
'AI insights are informational and based on recorded activity.',
style: PLDesign.caption.copyWith(height: 1.35),
),
),
const SizedBox(height: 12),

Row(
children: [
Expanded(
child: quickCard(
icon: Icons.warning_amber_rounded,
title: "Risk Level",
value: "Moderate",
color: PLDesign.warning,
),
),
const SizedBox(width: 14),
Expanded(
child: quickCard(
icon: Icons.verified_rounded,
title: "Compliance",
value: "92%",
color: PLDesign.success,
),
),
],
),

const SizedBox(height: 14),

Row(
children: [
Expanded(
child: quickCard(
icon: Icons.timeline_rounded,
title: "Events Flagged",
value: "3",
color: PLDesign.info,
),
),
const SizedBox(width: 14),
Expanded(
child: quickCard(
icon: Icons.psychology_alt_rounded,
title: "Tone Score",
value: "Stable",
color: PLDesign.ai,
),
),
],
),

const SizedBox(height: 26),

const Align(
alignment: Alignment.centerLeft,
child: Text(
"Recent AI Alerts",
style: TextStyle(
fontSize: 19,
fontWeight: FontWeight.w900,
color: Colors.white,
),
),
),

const SizedBox(height: 14),

alertTile(
title: "Late exchange pattern detected",
subtitle: "3 late arrivals in last 14 days",
color: PLDesign.warning,
),

alertTile(
title: "Escalating message tone trend",
subtitle: "Increased negative sentiment",
color: PLDesign.danger,
),

alertTile(
title: "Expense submission delay",
subtitle: "2 reimbursements pending",
color: PLDesign.info,
),

const SizedBox(height: 32),

pressable(
onTap: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => const AiFairnessSuggestionScreen(),
),
);
},
child: Container(
height: 62,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(20),
gradient: const LinearGradient(
colors: [
Color(0xff4f46e5),
Color(0xff1d4ed8),
],
),
boxShadow: [
BoxShadow(
color: const Color(0xff4f46e5)
.withValues(alpha: .35),
blurRadius: 28,
offset: const Offset(0, 16),
)
],
),
child: const Center(
child: Text(
"Open AI Fairness",
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w800,
fontSize: 16,
),
),
),
),
),

const SizedBox(height: 20),
],
),
),
);
}
}
