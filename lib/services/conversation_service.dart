import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_fields.dart';

class ConversationService {
static final _db = FirebaseFirestore.instance;

static Stream<QuerySnapshot> getUserConversations(String uid) {
return _db
.collection("conversations")
.where(FirestoreFields.memberIds, arrayContains: uid)
.orderBy("lastTimestamp", descending: true)
.snapshots();
}
}