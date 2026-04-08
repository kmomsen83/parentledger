import 'package:flutter/material.dart';
import 'proposal_resolution_screen.dart';

class ActiveNegotiationScreen extends StatelessWidget {

final Map<String,dynamic> proposal;

const ActiveNegotiationScreen({
super.key,
required this.proposal,
});

@override
Widget build(BuildContext context) {

return Scaffold(
appBar: AppBar(title: const Text("Negotiation")),

body: Center(
child: ElevatedButton(
child: const Text("Resolve Proposal"),
onPressed: (){
Navigator.push(
context,
MaterialPageRoute(
builder: (_) =>
ProposalResolutionScreen(proposal: proposal),
),
);
},
),
),
);
}
}
