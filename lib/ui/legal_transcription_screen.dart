import 'package:flutter/material.dart';
import '../services/message_service.dart';

class LegalTranscriptScreen extends StatefulWidget {
final String conversationId;

const LegalTranscriptScreen({super.key, required this.conversationId});

@override
State<LegalTranscriptScreen> createState() =>
_LegalTranscriptScreenState();
}

class _LegalTranscriptScreenState extends State<LegalTranscriptScreen> {

List<Map<String, dynamic>> messages = [];

@override
void initState() {
super.initState();
load();
}

Future<void> load() async {
final data =
await MessageService.getTranscript(widget.conversationId);

setState(() => messages = data);
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(title: const Text("Legal Transcript")),
body: ListView.builder(
itemCount: messages.length,
itemBuilder: (c, i) {
final m = messages[i];

return ListTile(
title: Text(m["text"] ?? ""),
subtitle: Text(
m["createdAt"]?.toString() ?? "",
),
);
},
),
);
}
}
