class RecurringPatternModel {
final String id;
final String childId;
final String type; // pickup / dropoff
final int weekday; // 1 = Mon → 7 = Sun
final String time; // "17:00"

RecurringPatternModel({
required this.id,
required this.childId,
required this.type,
required this.weekday,
required this.time,
});

factory RecurringPatternModel.fromDoc(doc) {
final d = doc.data();

return RecurringPatternModel(
id: doc.id,
childId: d["childId"],
type: d["type"],
weekday: d["weekday"],
time: d["time"],
);
}
}
