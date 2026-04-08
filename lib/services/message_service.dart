import 'package:cloud_firestore/cloud_firestore.dart';

class MessageService {
static final _db = FirebaseFirestore.instance;

/// ================================
/// 🔥 SEND MESSAGE (IMMUTABLE)
/// ================================
static Future<void> sendMessage({
required String conversationId,
required String senderId,
required String text,
String? exchangeId,
}) async {
final convoRef =
_db.collection("conversations").doc(conversationId);

final msgRef = convoRef.collection("messages").doc();

await msgRef.set({
"text": text,
"senderId": senderId,
"createdAt": FieldValue.serverTimestamp(),
"readAt": null,
"exchangeId": exchangeId,
"edited": false, // 🔒 locked forever
"deleted": false,
});

await convoRef.set({
"lastMessage": text,
"lastTimestamp": FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
}

/// ================================
/// 👁️ MARK READ
/// ================================
static Future<void> markRead({
required String conversationId,
required String messageId,
}) async {
await _db
.collection("conversations")
.doc(conversationId)
.collection("messages")
.doc(messageId)
.update({
"readAt": FieldValue.serverTimestamp(),
});
}

/// ================================
/// 📜 LEGAL EXPORT DATA
/// ================================
static Future<List<Map<String, dynamic>>> getTranscript(
String conversationId) async {
final snap = await _db
.collection("conversations")
.doc(conversationId)
.collection("messages")
.orderBy("createdAt")
.get();

return snap.docs.map((d) => d.data()).toList();
}
}
