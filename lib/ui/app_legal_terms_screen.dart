import 'package:flutter/material.dart';

class AppLegalTermsScreen extends StatefulWidget {
const AppLegalTermsScreen({super.key});

@override
State<AppLegalTermsScreen> createState() =>
_AppLegalTermsScreenState();
}

class _AppLegalTermsScreenState extends State<AppLegalTermsScreen> {
bool accepted = false;

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xff0f172a),

appBar: AppBar(
backgroundColor: const Color(0xff0f172a),
elevation: 0,
leading: IconButton(
icon: const Icon(Icons.arrow_back, color: Colors.white),
onPressed: () => Navigator.pop(context),
),
title: const Text(
"Terms & Legal Agreement",
style: TextStyle(
color: Colors.white,
fontWeight: FontWeight.w800,
),
),
centerTitle: true,
),

body: Column(
children: [

/// ===== TERMS BODY =====
Expanded(
child: SingleChildScrollView(
padding: const EdgeInsets.all(22),
child: Container(
padding: const EdgeInsets.all(24),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(28),
gradient: LinearGradient(
colors: [
Colors.white.withOpacity(.06),
Colors.white.withOpacity(.02),
],
),
border: Border.all(
color: Colors.white.withOpacity(.12),
),
),
child: const Text(
"""PARENTLEDGER USER AGREEMENT

IMPORTANT — PLEASE READ CAREFULLY.

1. NATURE OF SERVICE
ParentLedger is a communication documentation and co-parent coordination tool. It is NOT a law firm, legal advisor, therapist, mediator, or financial institution.

2. NO LEGAL ADVICE
All AI insights, fairness scores, tone analysis, behavioral alerts, and suggestions are informational only and must not be relied upon as legal guidance.

3. USER RESPONSIBILITY
Users are solely responsible for accuracy and legality of all messages, uploads, expense records, custody logs, and documents.

4. COURT USE DISCLAIMER
ParentLedger does not guarantee admissibility of exported timelines, summaries, or AI insights in any legal proceeding.

5. RECORDING CONSENT
Certain actions may be permanently logged to maintain historical timeline integrity.

6. MISUSE POLICY
Harassment, falsified evidence, intimidation, or manipulation attempts may result in account suspension.

7. DATA SECURITY
ParentLedger uses secure cloud storage and encrypted transmission. Absolute security cannot be guaranteed.

8. AI PROCESSING CONSENT
Users consent to automated content analysis for insights, compliance metrics, and dispute-prevention recommendations.

9. SUBSCRIPTION TERMS
Paid features require active subscription. Failure to maintain subscription may limit access.

10. LIMITATION OF LIABILITY
ParentLedger is not liable for custody outcomes, financial disputes, emotional distress, or reliance on AI output.

11. ACCOUNT TERMINATION
Accounts violating policy or law may be suspended or terminated.

12. ACCEPTANCE
By tapping “Accept & Continue” you confirm you have read and agreed to these terms.""",
style: TextStyle(
color: Colors.white70,
height: 1.7,
fontSize: 14.5,
),
),
),
),
),

/// ===== ACCEPT PANEL =====
Container(
padding: const EdgeInsets.all(22),
decoration: const BoxDecoration(
color: Color(0xff020617),
borderRadius: BorderRadius.vertical(
top: Radius.circular(30),
),
),
child: Column(
children: [

Row(
children: [
Checkbox(
value: accepted,
activeColor: const Color(0xff4f46e5),
onChanged: (v) {
setState(() {
accepted = v ?? false;
});
},
),
const Expanded(
child: Text(
"I have read and agree to the ParentLedger User Agreement",
style: TextStyle(
color: Colors.white70,
),
),
)
],
),

const SizedBox(height: 14),

GestureDetector(
onTap: accepted
? () {
Navigator.pop(context, true);
}
: null,
child: Container(
height: 60,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(20),
gradient: accepted
? const LinearGradient(
colors: [
Color(0xff6366f1),
Color(0xff2563eb),
],
)
: null,
color: accepted ? null : Colors.white12,
),
child: Center(
child: Text(
"Accept & Continue",
style: TextStyle(
color: accepted ? Colors.white : Colors.white38,
fontWeight: FontWeight.w800,
fontSize: 16,
),
),
),
),
),

const SizedBox(height: 10),

],
),
)

],
),
);
}
}
