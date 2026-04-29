import 'package:flutter/foundation.dart';

import 'case_event.dart';

/// Single view-model for `case_events` ledger rows — shared by Timeline UI and PDF export.
///
/// Populated only via [TimelineMapper.mapFromFirestore] so mapping stays unified.
@immutable
class TimelineEventModel {
  const TimelineEventModel({
    required this.id,
    required this.caseId,
    required this.type,
    required this.title,
    required this.description,
    required this.actorName,
    required this.actorId,
    required this.createdAt,
    required this.metadata,
  });

  final String id;
  final String caseId;

  /// Firestore `type` (e.g. [CaseEventTypes.message]).
  final String type;
  final String title;
  final String description;

  /// Denormalized name on the event document (may be empty; UI resolves via [actorId]).
  final String actorName;

  /// Actor Firebase UID — required for [TimelineActor] resolution.
  final String actorId;

  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  /// Same ordering key as [CaseEvent.timestamp].
  DateTime get timestamp => createdAt;

  bool get isExpenseLike =>
      type == 'expense' ||
      type == CaseEventTypes.expenseCreated ||
      type == CaseEventTypes.expenseApproved ||
      type == CaseEventTypes.expenseDenied;

  bool get isScheduleLike =>
      type == 'exchange' ||
      type == CaseEventTypes.scheduleCreated ||
      type == CaseEventTypes.scheduleUpdated;

  bool get isMessageLike =>
      type == CaseEventTypes.message ||
      type == 'message' ||
      type == 'message_sent';
}
