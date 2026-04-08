import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationService {
static final _db = FirebaseFirestore.instance;

static Stream<QuerySnapshot> getUserConversations(String uid) {
return _db
.collection("conversations")
.where("participants", arrayContains: uid)
.orderBy("lastTimestamp", descending: true)
.snapshots();
}
}