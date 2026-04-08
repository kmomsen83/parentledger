import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/conversation_service.dart';
import 'conversation_thread_screen.dart';

class MessagesInboxScreen extends StatelessWidget {
const MessagesInboxScreen({super.key});

String get uid => FirebaseAuth.instance.currentUser!.uid;

void openThread(
BuildContext context,
String threadId,
) {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => ConversationThreadScreen(
title: "Conversation",
conversationId: threadId,
),
),
);
}

String formatTime(Timestamp? ts) {
if (ts == null) return "";

final dt = ts.toDate();
final now = DateTime.now();

if (now.difference(dt).inDays == 0) {
// today → show time
return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
}

if (now.difference(dt).inDays < 7) {
// this week → show weekday
return ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][dt.weekday - 1];
}

return "${dt.month}/${dt.day}";
}

Widget threadTile(
BuildContext context,
String id,
Map<String, dynamic> data,
) {
final lastMessage = data["lastMessage"] ?? "";
final timestamp = data["lastTimestamp"] as Timestamp?;

return GestureDetector(
onTap: () => openThread(context, id),
child: Container(
margin: const EdgeInsets.only(bottom: 14),
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(18),
boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(.04),
blurRadius: 10,
offset: const Offset(0, 6),
)
],
),
child: Row(
children: [
/// Avatar
CircleAvatar(
radius: 24,
backgroundColor: Colors.blue.withOpacity(.1),
child: const Icon(
Icons.person,
color: Colors.blue,
),
),

const SizedBox(width: 14),

/// Text
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
"Conversation",
style: TextStyle(
fontWeight: FontWeight.bold,
fontSize: 16,
),
),
const SizedBox(height: 6),
Text(
lastMessage,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: Colors.black54,
),
),
],
),
),

/// Time
Text(
formatTime(timestamp),
style: const TextStyle(
fontSize: 12,
color: Colors.black45,
),
),
],
),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xfff5f6fb),

appBar: AppBar(
title: const Text("Messages"),
elevation: 0,
backgroundColor: Colors.white,
foregroundColor: Colors.black,
),

body: StreamBuilder<QuerySnapshot>(
stream: ConversationService.getUserConversations(uid),
builder: (context, snapshot) {
if (snapshot.connectionState == ConnectionState.waiting) {
return const Center(
child: CircularProgressIndicator(),
);
}

if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
return const Center(
child: Text("No conversations yet"),
);
}

final docs = snapshot.data!.docs;

return ListView.builder(
padding: const EdgeInsets.all(16),
itemCount: docs.length,
itemBuilder: (context, i) {
final doc = docs[i];
final data = doc.data() as Map<String, dynamic>;

return threadTile(
context,
doc.id,
data,
);
},
);
},
),
);
}
}
