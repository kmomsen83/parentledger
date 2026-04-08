import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/case_context.dart';
import '../../services/exchange_timeline_service.dart';
import '../../models/exchange_timeline_event.dart';
import '../../design/design.dart';

class ExchangeTimelineScreen extends StatelessWidget {

final String exchangeId;

const ExchangeTimelineScreen({
super.key,
required this.exchangeId,
});

@override
Widget build(BuildContext context) {

final caseId = context.watch<CaseContext>().caseId;

if (caseId == null) {
return const Scaffold(
body: Center(child: CircularProgressIndicator()),
);
}

return Scaffold(
backgroundColor: PLDesign.background,
appBar: AppBar(
title: const Text("Exchange Timeline"),
),
body: StreamBuilder<List<ExchangeTimelineEvent>>(
stream: ExchangeTimelineService.watchTimeline(
caseId: caseId,
exchangeId: exchangeId,
),
builder: (context, snap) {

if (!snap.hasData) {
return const Center(
child: CircularProgressIndicator(),
);
}

final events = snap.data!;

if (events.isEmpty) {
return const Center(
child: Text(
"No events yet",
style: PLDesign.caption,
),
);
}

return ListView.builder(
padding: const EdgeInsets.all(20),
itemCount: events.length,
itemBuilder: (_, i) {

final e = events[i];

return Container(
margin: const EdgeInsets.only(bottom: 14),
padding: const EdgeInsets.all(18),
decoration: PLDesign.gradientCard,
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [

Text(
e.type.toUpperCase(),
style: PLDesign.sectionTitle,
),

const SizedBox(height: 6),

Text(
e.timestamp.toString(),
style: PLDesign.caption,
),

if (e.notes != null)
Padding(
padding:
const EdgeInsets.only(top: 6),
child: Text(
e.notes!,
style: PLDesign.body,
),
),

],
),
);
},
);
},
),
);
}
}
