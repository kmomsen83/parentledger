import 'package:flutter/material.dart';
import 'package:parentledger/design/design.dart';

class PendingExpensesDetailScreen extends StatelessWidget {
const PendingExpensesDetailScreen({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: PLDesign.background,
body: Container(
decoration: const BoxDecoration(
gradient: PLDesign.pageGradient,
),
child: SafeArea(
child: ListView(
padding: const EdgeInsets.all(24),
children: [

/// ⭐ HEADER
Row(
children: [
IconButton(
icon: const Icon(Icons.arrow_back_ios_new,
color: Colors.white70),
onPressed: () => Navigator.pop(context),
),
const SizedBox(width: 6),
const Text(
"Pending Expense",
style: PLDesign.pageTitle,
),
],
),

const SizedBox(height: 32),

/// ⭐ EXPENSE CARD
Container(
padding: const EdgeInsets.all(22),
decoration: PLDesign.elevatedCard,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

const Text(
"\$142.50",
style: PLDesign.statNumber,
),

const SizedBox(height: 6),

const Text(
"Soccer Registration Fee",
style: PLDesign.sectionTitle,
),

const SizedBox(height: 14),

const Row(
children: [
Icon(Icons.calendar_today,
size: 16,
color: PLDesign.textMuted),
SizedBox(width: 6),
Text(
"Submitted May 4",
style: PLDesign.caption,
)
],
),

const SizedBox(height: 10),

const Row(
children: [
Icon(Icons.person_outline,
size: 16,
color: PLDesign.textMuted),
SizedBox(width: 6),
Text(
"Submitted by Co-Parent",
style: PLDesign.caption,
)
],
),

const SizedBox(height: 18),

Container(
padding: const EdgeInsets.all(14),
decoration: PLDesign.alertWarning,
child: const Row(
children: [
Icon(Icons.schedule,
color: PLDesign.warning,
size: 18),
SizedBox(width: 8),
Expanded(
child: Text(
"Awaiting your approval",
style: TextStyle(
color: PLDesign.warning,
fontWeight: FontWeight.w600,
),
),
)
],
),
)
],
),
),

const SizedBox(height: 30),

/// ⭐ SPLIT CARD
Container(
padding: const EdgeInsets.all(22),
decoration: PLDesign.elevatedCard,
child: const Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

Text(
"Expense Split",
style: PLDesign.sectionTitle,
),

SizedBox(height: 16),

Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
Text("Your Share", style: PLDesign.body),
Text("\$71.25",
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w700))
],
),

SizedBox(height: 10),

Row(
mainAxisAlignment:
MainAxisAlignment.spaceBetween,
children: [
Text("Co-Parent Share",
style: PLDesign.body),
Text("\$71.25",
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w700))
],
),
],
),
),

const SizedBox(height: 34),

/// ⭐ ACTIONS
Row(
children: [

Expanded(
child: GestureDetector(
onTap: () {},
child: Container(
height: 56,
decoration: BoxDecoration(
borderRadius: PLDesign.r16,
border: Border.all(
color: PLDesign.danger),
),
child: const Center(
child: Text(
"Deny",
style: TextStyle(
color: PLDesign.danger,
fontWeight: FontWeight.w700,
),
),
),
),
),
),

const SizedBox(width: 16),

Expanded(
child: GestureDetector(
onTap: () {},
child: Container(
height: 56,
decoration: BoxDecoration(
gradient: PLDesign.primaryGradient,
borderRadius: PLDesign.r16,
boxShadow: PLDesign.glowShadow,
),
child: const Center(
child: Text(
"Approve",
style: PLDesign.buttonText,
),
),
),
),
),
],
),

const SizedBox(height: 40),
],
),
),
),
);
}
}
