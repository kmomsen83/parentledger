import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/case_event.dart';
import '../models/timeline_event_model.dart';

/// Maps Firestore `case_events` docs → [TimelineEventModel].
///
/// Delegates parsing to [CaseEvent.fromDoc] so UI and PDF never diverge on field semantics.
class TimelineMapper {
  TimelineMapper._();

  static TimelineEventModel mapFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final e = CaseEvent.fromDoc(doc);
    return TimelineEventModel(
      id: e.id,
      caseId: e.caseId,
      type: e.type,
      title: e.title,
      description: e.description,
      actorName: e.actorName,
      actorId: e.actorId,
      createdAt: e.createdAt,
      metadata: Map<String, dynamic>.from(e.metadata),
    );
  }
}
