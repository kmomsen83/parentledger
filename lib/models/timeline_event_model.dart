import 'package:cloud_firestore/cloud_firestore.dart';

class TimelineEventModel {

final String id;
final String type;
final String title;
final String? notes;
final DateTime date;
final DateTime createdAt;

TimelineEventModel({
required this.id,
required this.type,
required this.title,
this.notes,
required this.date,
required this.createdAt,
});

factory TimelineEventModel.fromDoc(DocumentSnapshot doc) {

final d = doc.data() as Map<String, dynamic>;

return TimelineEventModel(
id: doc.id,
type: d["type"] ?? "note",
title: d["title"] ?? "",
notes: d["notes"],
date: (d["date"] as Timestamp).toDate(),
createdAt: (d["createdAt"] as Timestamp).toDate(),
);
}
}
