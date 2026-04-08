import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
const TermsScreen({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xff0f172a),
appBar: AppBar(
title: const Text("Terms & Privacy"),
backgroundColor: Colors.transparent,
elevation: 0,
),
body: SafeArea(
child: Column(
children: [
const Expanded(
child: SingleChildScrollView(
padding: EdgeInsets.all(24),
child: Text(
_termsText,
style: TextStyle(
color: Colors.white70,
fontSize: 14,
height: 1.5,
),
),
),
),

Padding(
padding: const EdgeInsets.all(20),
child: GestureDetector(
onTap: () {
Navigator.pop(context, true);
},
child: Container(
height: 60,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(28),
gradient: const LinearGradient(
colors: [
Color(0xff76c3ff),
Color(0xff3d7cff),
],
),
),
child: const Center(
child: Text(
"I Agree",
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w800,
),
),
),
),
),
)
],
),
),
);
}
}

const String _termsText = """

PARENTLEDGER TERMS OF SERVICE & PRIVACY SUMMARY

Effective Use of Platform

ParentLedger provides tools to help co-parents document custody events, communicate, and organize shared parenting responsibilities.

ParentLedger is NOT a legal service, law firm, mediation provider, therapist, or custody authority.

Users remain solely responsible for all parenting decisions and legal actions.

Attorney & Professional Viewer Access

Users may grant viewing access to attorneys, mediators, therapists, court professionals, or other third parties.

ParentLedger does not verify the identity, credentials, or authority of invited viewers.

Users assume full responsibility for granting and revoking access.

Information Accuracy & Evidence Use

ParentLedger does not guarantee the accuracy, completeness, or admissibility of any records created within the platform.

Exported logs and reports are user-generated content.

ParentLedger is not responsible for how records are interpreted, used, or presented in legal proceedings.

Third-Party Sharing & Screenshots

Users may export or share platform content outside the application.

ParentLedger is not liable for:

• screenshots
• forwarded messages
• redistributed custody records
• unauthorized disclosure

Professional Conduct

Users agree not to use ParentLedger for harassment, threats, manipulation, or abuse.

Accounts may be suspended or terminated for misuse.

Subscription & Billing

ParentLedger may offer paid subscriptions.

Failure to maintain an active subscription may limit platform features.

Data Storage & Security

ParentLedger uses commercially reasonable safeguards but cannot guarantee absolute security.

Limitation of Liability

To the maximum extent permitted by law, ParentLedger shall not be liable for indirect, emotional, legal, financial, or consequential damages arising from platform use.

Dispute Resolution

Users agree to binding arbitration and waive class-action rights where legally permitted.

Account Termination

ParentLedger may suspend or terminate accounts at its discretion to protect platform integrity.

By using ParentLedger you agree to these terms.

""";
