import 'package:cloud_firestore/cloud_firestore.dart';

class ExchangeGeneratorService {

static final _db = FirebaseFirestore.instance;

static Future<void> generateNext30Days({
required String caseId,
}) async {

final patterns = await _db
.collection("cases")
.doc(caseId)
.collection("recurring_patterns")
.get();

final now = DateTime.now();
final end = now.add(const Duration(days: 30));

for (final p in patterns.docs) {

final data = p.data();

final int weekday = data["weekday"];
final String time = data["time"];
final String childId = data["childId"];
final String type = data["type"];

DateTime cursor = now;

while (cursor.isBefore(end)) {

if (cursor.weekday == weekday) {

final parts = time.split(":");

final exchangeTime = DateTime(
cursor.year,
cursor.month,
cursor.day,
int.parse(parts[0]),
int.parse(parts[1]),
);

/// ⭐ prevent duplicates
final existing = await _db
.collection("cases")
.doc(caseId)
.collection("exchanges")
.where("scheduledTime",
isEqualTo: Timestamp.fromDate(exchangeTime))
.get();

if (existing.docs.isEmpty) {

await _db
.collection("cases")
.doc(caseId)
.collection("exchanges")
.add({

"childId": childId,
"type": type,
"scheduledTime": Timestamp.fromDate(exchangeTime),
"status": "scheduled",
"createdAt": Timestamp.now(),

});

}

}

cursor = cursor.add(const Duration(days: 1));
}

}

}

}
