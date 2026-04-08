import 'package:flutter/material.dart';

class ProposalResolutionScreen extends StatelessWidget {

final Map<String,dynamic> proposal;

const ProposalResolutionScreen({
super.key,
required this.proposal,
});

@override
Widget build(BuildContext context) {

return Scaffold(
appBar: AppBar(title: const Text("Resolution")),

body: Center(
child: Text(
"Resolved: ${proposal["title"]}",
style: const TextStyle(fontSize: 22),
),
),
);
}
}