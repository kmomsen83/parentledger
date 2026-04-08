import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/message_service.dart';
import '../services/ai_service.dart';
import '../ui/legal_transcription_screen.dart';

class ConversationThreadScreen extends StatefulWidget {
final String title;
final String conversationId;
final String? exchangeId;

const ConversationThreadScreen({
super.key,
required this.title,
required this.conversationId,
this.exchangeId,
});

@override
State<ConversationThreadScreen> createState() =>
_ConversationThreadScreenState();
}

class _ConversationThreadScreenState
extends State<ConversationThreadScreen> {

final TextEditingController controller =
TextEditingController();

String get uid => FirebaseAuth.instance.currentUser!.uid;

bool showWarning = false;

Future<void> send() async {
final text = controller.text.trim();
if (text.isEmpty) return;

final conflict = AIService.isHighConflict(text);

if (conflict) {
setState(() => showWarning = true);
return;
}

await MessageService.sendMessage(
conversationId: widget.conversationId,
senderId: uid,
text: text,
exchangeId: widget.exchangeId,
);

controller.clear();
}

Widget bubble(Map<String, dynamic> m) {
final mine = m["senderId"] == uid;

return Align(
alignment:
mine ? Alignment.centerRight : Alignment.centerLeft,
child: Container(
padding: const EdgeInsets.all(14),
margin: const EdgeInsets.only(bottom: 10),
decoration: BoxDecoration(
color: mine ? Colors.blue : Colors.white,
borderRadius: BorderRadius.circular(16),
),
child: Text(
m["text"],
style: TextStyle(
color: mine ? Colors.white : Colors.black),
),
),
);
}

@override
Widget build(BuildContext context) {

final stream = FirebaseFirestore.instance
.collection("conversations")
.doc(widget.conversationId)
.collection("messages")
.orderBy("createdAt")
.snapshots();

return Scaffold(
appBar: AppBar(
title: Text(widget.title),
actions: [
IconButton(
icon: const Icon(Icons.upload_file),
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => LegalTranscriptScreen(
conversationId: widget.conversationId),
),
);
},
),
],
),

body: Column(
children: [

if (showWarning)
Container(
color: Colors.red.withOpacity(.1),
padding: const EdgeInsets.all(12),
child: Row(
children: [
const Icon(Icons.warning, color: Colors.red),
const SizedBox(width: 8),
const Expanded(
child: Text(
"Message may escalate conflict"),
),
TextButton(
onPressed: () {
controller.text =
AIService.rewrite(controller.text);
setState(() => showWarning = false);
},
child: const Text("Rewrite"),
)
],
),
),

Expanded(
child: StreamBuilder<QuerySnapshot>(
stream: stream,
builder: (c, s) {
if (!s.hasData) {
return const Center(
child: CircularProgressIndicator());
}

final docs = s.data!.docs;

return ListView(
padding: const EdgeInsets.all(16),
children: docs
.map((d) => bubble(
d.data() as Map<String, dynamic>))
.toList(),
);
},
),
),

Row(
children: [
Expanded(
child: TextField(
controller: controller,
),
),
IconButton(
icon: const Icon(Icons.send),
onPressed: send,
)
],
)
],
),
);
}
}
