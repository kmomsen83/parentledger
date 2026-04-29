import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified audit row in `case_events/{id}` (server ledger) or legacy `caseEvents`.
///
/// **New schema:** title, description, actorId, actorName, createdAt, metadata.
/// **Legacy:** timestamp, createdBy, data — still parsed in [fromDoc].
class CaseEvent {
  final String id;
  final String caseId;

  /// Canonical type, e.g. [CaseEventTypes.message], or legacy `expense` / `exchange`.
  final String type;
  final String title;
  final String description;
  final String actorId;
  final String actorName;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const CaseEvent({
    required this.id,
    required this.caseId,
    required this.type,
    required this.title,
    required this.description,
    required this.actorId,
    required this.actorName,
    required this.createdAt,
    required this.metadata,
  });

  /// Unified metadata bucket for exports/PDF (legacy stored rows in [metadata]).
  Map<String, dynamic> get data => metadata;

  /// Sorting / display time (legacy docs used `timestamp`).
  DateTime get timestamp => createdAt;

  String get createdBy => actorId;

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

  factory CaseEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final createdAtTs = map['createdAt'] ?? map['timestamp'];
    final createdAt = createdAtTs is Timestamp
        ? createdAtTs.toDate()
        : DateTime.now();

    final caseId = (map['caseId'] ?? '').toString();
    final type = (map['type'] ?? '').toString();
    final meta = Map<String, dynamic>.from(
      map['metadata'] as Map? ?? map['data'] as Map? ?? {},
    );

    final hasNewShape =
        map.containsKey('actorId') && (map.containsKey('title') || map.containsKey('description'));

    if (hasNewShape) {
      return CaseEvent(
        id: doc.id,
        caseId: caseId,
        type: type,
        title: (map['title'] ?? '').toString(),
        description: (map['description'] ?? '').toString(),
        actorId: (map['actorId'] ?? '').toString(),
        actorName: (map['actorName'] ?? '').toString(),
        createdAt: createdAt,
        metadata: meta,
      );
    }

    final legacyData = Map<String, dynamic>.from(map['data'] as Map? ?? <String, dynamic>{});
    final createdBy = (map['createdBy'] ?? '').toString();

    final derived = _deriveLegacyPresentation(type, legacyData);
    return CaseEvent(
      id: doc.id,
      caseId: caseId,
      type: type,
      title: derived.title,
      description: derived.description,
      actorId: createdBy,
      actorName: '',
      createdAt: createdAt,
      metadata: legacyData,
    );
  }

  /// Serialize **new** schema only (backfill / tests).
  Map<String, dynamic> toFirestoreMap({
    Timestamp? createdAtOverride,
  }) {
    return <String, dynamic>{
      'caseId': caseId,
      'type': type,
      'title': title,
      'description': description,
      'actorId': actorId,
      'actorName': actorName,
      'createdAt': createdAtOverride ?? Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }
}

class CaseEventTypes {
  CaseEventTypes._();

  static const message = 'message';
  static const expenseCreated = 'expense_created';
  static const expenseApproved = 'expense_approved';
  static const expenseDenied = 'expense_denied';
  static const scheduleCreated = 'schedule_created';
  static const scheduleUpdated = 'schedule_updated';
  static const statusChange = 'status_change';

  static const proposalUpdated = 'proposal_updated';
  static const proposalAccepted = 'proposal_accepted';
  static const proposalRejected = 'proposal_rejected';
  static const proposalFinalized = 'proposal_finalized';
}

class _LegacyPresentation {
  const _LegacyPresentation({required this.title, required this.description});
  final String title;
  final String description;
}

_LegacyPresentation _deriveLegacyPresentation(
  String type,
  Map<String, dynamic> data,
) {
  switch (type) {
    case 'expense':
      return _LegacyPresentation(
        title: 'Expense',
        description: (data['description'] ?? '').toString(),
      );
    case 'exchange':
      return _LegacyPresentation(
        title: 'Schedule',
        description: (data['locationName'] ?? '').toString(),
      );
    case 'message':
      return _LegacyPresentation(
        title: 'Message',
        description: (data['text'] ?? '').toString(),
      );
    case 'document':
      return _LegacyPresentation(
        title: 'Document',
        description: (data['fileName'] ?? '').toString(),
      );
    default:
      return _LegacyPresentation(
        title: type.isEmpty ? 'Event' : type,
        description: '',
      );
  }
}
