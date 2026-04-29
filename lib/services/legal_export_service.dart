import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parentledger/models/case_event.dart';
import 'package:parentledger/models/legal_export_models.dart';

import 'case_event_service.dart';
import 'notification_service.dart';

/// Legal / court exports — prefer unified [caseEvents] for chronological data.
class LegalExportService {
  final _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// [caseId] should be passed from UI when the active case can differ from
  /// `users/{uid}.caseId` (e.g. attorney multi-case).
  Future<ExportDocument> generate(
    String type, {
    String? caseId,
  }) async {
    final id = caseId ?? await _getCaseIdFromUserDoc();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    ExportDocument doc;

    switch (type) {
      case 'full':
        doc = await _full(id);
        break;
      case 'timeline':
        doc = await _timeline(id);
        break;
      case 'expenses':
        doc = await _expenses(id);
        break;
      case 'violations':
        doc = await _violations(id);
        break;
      default:
        throw Exception('Invalid export type');
    }
    if (uid != null) {
      await NotificationService.notifyReportGenerated(
        caseId: id,
        userId: uid,
        reportTitle: doc.title,
      );
    }
    return doc;
  }

  /// Court Case Export screen — composes sections from toggles. Uses
  /// [CaseEvent] stream plus timeline rows for formal violation flags.
  Future<ExportDocument> generateCourtBundle({
    required String caseId,
    required bool includeTimeline,
    required bool includeParenting,
    required bool includeExpenses,
    required bool includeMessages,
    required bool includeViolations,
    required bool includeAiNarrative,
  }) async {
    await _ensureCaseEventsBackfill(caseId);
    final events = await CaseEventService.fetchCaseEvents(caseId);

    final sections = <ExportSection>[];

    if (includeTimeline) {
      final entries = events.map(_exportEntryForCaseEvent).toList();
      if (entries.isNotEmpty) {
        sections.add(
          ExportSection(
            header: 'Case events (chronological)',
            entries: entries,
          ),
        );
      }
    }

    if (includeParenting && !includeTimeline) {
      final ex = events.where((e) => e.isScheduleLike).map(_exportEntryForCaseEvent).toList();
      if (ex.isNotEmpty) {
        sections.add(ExportSection(header: 'Parenting time (exchanges)', entries: ex));
      }
    }

    if (includeExpenses && !includeTimeline) {
      final exp = events.where((e) => e.isExpenseLike).toList();
      if (exp.isNotEmpty) {
        var total = 0.0;
        var unpaid = 0.0;
        final summable = exp
            .where(
              (e) => e.type == 'expense' || e.type == CaseEventTypes.expenseCreated,
            )
            .toList();
        for (final e in summable) {
          final amount = _readAmount(e.metadata['amount'] ?? e.metadata['Amount']);
          final paid = e.metadata['paid'] == true || e.metadata['status'] == 'paid';
          total += amount;
          if (!paid) unpaid += amount;
        }
        sections.add(
          ExportSection(
            header: 'Expense summary',
            entries: [
              ExportEntry(
                timestamp: DateTime.now(),
                title: 'Totals',
                description:
                    'Total: \$${total.toStringAsFixed(2)} | Outstanding: \$${unpaid.toStringAsFixed(2)}',
              ),
            ],
          ),
        );
        sections.add(
          ExportSection(
            header: 'Detailed expenses',
            entries: exp.map(_exportEntryForCaseEvent).toList(),
          ),
        );
      }
    }

    if (includeMessages && !includeTimeline) {
      final msg = events.where((e) => e.isMessageLike).map(_exportEntryForCaseEvent).toList();
      if (msg.isNotEmpty) {
        sections.add(ExportSection(header: 'Messages', entries: msg));
      }
    }

    if (includeViolations) {
      final vEntries = _violationEntriesFromCaseEvents(events);
      if (vEntries.isNotEmpty) {
        sections.add(ExportSection(header: 'Violations and flags', entries: vEntries));
      }
    }

    if (includeAiNarrative) {
      sections.add(
        ExportSection(
          header: 'Narrative summary',
          entries: [
            ExportEntry(
              timestamp: DateTime.now(),
              title: 'Overview',
              description:
                  'This section highlights documented activity in ParentLedger. '
                  'It does not constitute legal advice. For deeper analysis, use Case Insights and '
                  'the unified timeline in the app.',
            ),
          ],
        ),
      );
    }

    if (sections.isEmpty) {
      sections.add(
        ExportSection(
          header: 'No data',
          entries: [
            ExportEntry(
              timestamp: DateTime.now(),
              title: 'No matching records',
              description: 'Enable at least one section and ensure the case has activity to export.',
            ),
          ],
        ),
      );
    }

    final doc = ExportDocument(
      title: 'Court Case Export',
      generatedAt: DateTime.now(),
      caseId: caseId,
      sections: sections,
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await NotificationService.notifyReportGenerated(
        caseId: caseId,
        userId: uid,
        reportTitle: doc.title,
      );
    }
    return doc;
  }

  // ---------------------------------------------------------------------------
  // Case id
  // ---------------------------------------------------------------------------

  Future<String> _getCaseIdFromUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final doc = await _db.collection('users').doc(user.uid).get();
    final caseId = doc.data()?['caseId'];
    if (caseId == null || caseId.toString().isEmpty) {
      throw Exception('No caseId');
    }
    return caseId.toString();
  }

  // ---------------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------------

  Future<void> _ensureCaseEventsBackfill(String caseId) async {
    var list = await CaseEventService.fetchCaseEvents(caseId);
    if (list.isEmpty) {
      await CaseEventService.backfillCaseEvents(caseId);
    }
  }

  Future<ExportDocument> _full(
    String caseId, {
    String title = 'Full Case Report',
  }) async {
    await _ensureCaseEventsBackfill(caseId);
    final events = await CaseEventService.fetchCaseEvents(caseId);
    final entries = events.map(_exportEntryForCaseEvent).toList();

    return ExportDocument(
      title: title,
      generatedAt: DateTime.now(),
      caseId: caseId,
      sections: [
        ExportSection(
          header: 'Case events (chronological)',
          entries: entries,
        ),
      ],
    );
  }

  /// Chronological view of the same unified case events.
  Future<ExportDocument> _timeline(String caseId) async {
    return _full(caseId, title: 'Timeline Report');
  }

  /// Expense-only: derived from [caseEvents] (expense type).
  Future<ExportDocument> _expenses(String caseId) async {
    await _ensureCaseEventsBackfill(caseId);
    final events = await CaseEventService.fetchCaseEvents(caseId);
    final exp = events.where((e) => e.isExpenseLike).toList();

    var total = 0.0;
    var unpaid = 0.0;
    final summable = exp
        .where(
          (e) => e.type == 'expense' || e.type == CaseEventTypes.expenseCreated,
        )
        .toList();
    for (final e in summable) {
      final amount = _readAmount(e.metadata['amount']);
      final paid = e.metadata['paid'] == true || e.metadata['status'] == 'paid';
      total += amount;
      if (!paid) unpaid += amount;
    }

    final entries = exp.map(_exportEntryForCaseEvent).toList();

    return ExportDocument(
      title: 'Expense Report',
      generatedAt: DateTime.now(),
      caseId: caseId,
      sections: [
        ExportSection(
          header: 'Summary',
          entries: [
            ExportEntry(
              timestamp: DateTime.now(),
              title: 'Totals',
              description:
                  'Total: \$${total.toStringAsFixed(2)} | Outstanding: \$${unpaid.toStringAsFixed(2)}',
            ),
          ],
        ),
        ExportSection(
          header: 'Detailed expenses',
          entries: entries,
        ),
      ],
    );
  }

  /// Flags and formal concerns from [caseEvents] (e.g. communication flagged).
  Future<ExportDocument> _violations(String caseId) async {
    await _ensureCaseEventsBackfill(caseId);
    final events = await CaseEventService.fetchCaseEvents(caseId);
    final entries = _violationEntriesFromCaseEvents(events);

    return ExportDocument(
      title: 'Violation Report',
      generatedAt: DateTime.now(),
      caseId: caseId,
      sections: [
        ExportSection(
          header: 'Recorded violations and flags',
          entries: entries.isEmpty
              ? [
                  ExportEntry(
                    timestamp: DateTime.now(),
                    title: 'No records',
                    description: 'No violation or exchange-miss flags in the case timeline for this pull.',
                  ),
                ]
              : entries,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  ExportEntry _exportEntryForCaseEvent(CaseEvent event) {
    if (event.title.isNotEmpty || event.description.isNotEmpty) {
      final metaBits = <String>[];
      final flag = event.metadata['legalFlag']?.toString();
      if (flag != null && flag.isNotEmpty) metaBits.add('Flag: $flag');
      if (event.isExpenseLike) {
        final amount = _readAmount(event.metadata['amount']);
        final st = event.metadata['status']?.toString();
        if (st != null && st.isNotEmpty) metaBits.add('Status: $st');
        if (amount > 0) metaBits.add('\$${amount.toStringAsFixed(2)}');
      }
      return ExportEntry(
        timestamp: event.createdAt,
        title: event.title.isNotEmpty ? event.title : event.type,
        description:
            event.description.isNotEmpty ? event.description : event.metadata.toString(),
        metadata: metaBits.isEmpty ? null : metaBits.join(' · '),
      );
    }

    switch (event.type) {
      case 'expense':
        final amount = _readAmount(event.metadata['amount']);
        final paid = event.metadata['paid'] == true;
        return ExportEntry(
          timestamp: event.timestamp,
          title: 'Expense',
          description:
              '\$${amount.toStringAsFixed(2)} ${event.metadata['description'] ?? ''}'.trim(),
          metadata: paid ? 'Paid' : 'Unpaid',
        );
      case 'exchange':
        final location = (event.metadata['locationName'] ?? '').toString();
        final when = (event.metadata['scheduledTime'] ?? '').toString();
        return ExportEntry(
          timestamp: event.timestamp,
          title: 'Exchange',
          description: 'Scheduled at $location',
          metadata: when.isEmpty ? null : when,
        );
      case 'message':
        final body = (event.metadata['text'] ?? '').toString();
        final flag = (event.metadata['legalFlag'] ?? '').toString();
        return ExportEntry(
          timestamp: event.timestamp,
          title: 'Message',
          description: body,
          metadata: flag.isEmpty ? null : 'Flag: $flag',
        );
      case 'document':
        final name = (event.metadata['fileName'] ?? '').toString();
        final docType = (event.metadata['documentType'] ?? '').toString();
        return ExportEntry(
          timestamp: event.timestamp,
          title: 'Document',
          description: name.isEmpty ? 'Uploaded document' : name,
          metadata: docType.isEmpty ? null : 'Type: $docType',
        );
      default:
        return ExportEntry(
          timestamp: event.timestamp,
          title: event.type.isEmpty ? 'Event' : event.type,
          description: event.metadata.toString(),
        );
    }
  }

  List<ExportEntry> _violationEntriesFromCaseEvents(List<CaseEvent> events) {
    bool isViolation(CaseEvent e) {
      final flag = e.metadata['legalFlag']?.toString();
      if (flag != null && flag.isNotEmpty) return true;
      if (e.type == CaseEventTypes.statusChange) {
        final tl = e.title.toLowerCase();
        if (tl.contains('flag')) return true;
      }
      return false;
    }

    final rows = events.where(isViolation).toList();
    rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return rows
        .map(
          (e) => ExportEntry(
            timestamp: e.createdAt,
            title: e.title.isNotEmpty ? e.title : e.type,
            description: e.description.isNotEmpty ? e.description : e.metadata.toString(),
            metadata: e.actorName.isNotEmpty ? 'Actor: ${e.actorName}' : null,
          ),
        )
        .toList();
  }

  double _readAmount(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}
