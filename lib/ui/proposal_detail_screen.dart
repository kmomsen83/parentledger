import 'package:flutter/material.dart';
import 'active_negotiation_screen.dart';
import 'proposal_resolution_screen.dart';

class ProposalDetailScreen extends StatelessWidget {

final Map<String,dynamic> proposal;

const ProposalDetailScreen({
super.key,
required this.proposal,
});

@override
Widget build(BuildContext context) {

return Scaffold(
appBar: AppBar(title: const Text("Proposal Detail")),

body: Padding(
padding: const EdgeInsets.all(20),
child: Column(
children: [

Text(
proposal["title"],
style: const TextStyle(
fontSize: 24,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 10),

Text("Child: ${proposal["child"]}"),

const SizedBox(height: 30),

ElevatedButton(
child: const Text("Start Negotiation"),
onPressed: (){
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
ActiveNegotiationScreen(proposal: proposal),
),
);
},
),

const SizedBox(height: 10),

ElevatedButton(
child: const Text("Go To Resolution"),
onPressed: (){
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
ProposalResolutionScreen(proposal: proposal),
),
);
},
)

],
),
),
);
}
}
