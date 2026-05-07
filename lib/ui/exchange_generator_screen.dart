import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/case_context.dart';
import '../../services/exchange_generator_service.dart';
import '../../design/design.dart';

class ExchangeGeneratorScreen extends StatefulWidget {
const ExchangeGeneratorScreen({super.key});

@override
State<ExchangeGeneratorScreen> createState() =>
_ExchangeGeneratorScreenState();
}

class _ExchangeGeneratorScreenState
extends State<ExchangeGeneratorScreen> {

bool generating = false;

Future<void> generate() async {

final caseId = context.read<CaseContext>().caseId;

if (caseId == null) return;

setState(() => generating = true);

await ExchangeGeneratorService.generateNext30Days(
caseId: caseId,
);

setState(() => generating = false);

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text("Next 30 days exchanges generated"),
),
);

}

@override
Widget build(BuildContext context) {

return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(
title: const Text("Generate Exchanges"),
),
body: Padding(
padding: const EdgeInsets.all(20),
child: Column(
children: [

Container(
padding: const EdgeInsets.all(24),
decoration: PLDesign.gradientCard,
child: const Text(
"Generate real custody exchanges from recurring patterns.",
style: PLDesign.body,
),
),

const SizedBox(height: 30),

ElevatedButton(
onPressed: generating ? null : generate,
child: generating
? const CircularProgressIndicator()
: const Text("Generate Next 30 Days"),
),

],
),
),
);
}
}
