import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/case_event.dart';
import '../models/negotiation_proposal.dart';
import 'event_logger_service.dart';

/// Firestore: `proposals/{id}` and `proposals/{id}/messages`.
class ProposalService {
  ProposalService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _proposalsCol() =>
      _db.collection('proposals');

  static CollectionReference<Map<String, dynamic>> _messagesCol(
    String proposalId,
  ) =>
      _proposalsCol().doc(proposalId).collection('messages');

  // ---------------------------------------------------------------------------
  // State machine
  // ---------------------------------------------------------------------------

  static bool canTransition(String from, String to) {
    const pending = ProposalStatuses.pending;
    const negotiating = ProposalStatuses.negotiating;
    const accepted = ProposalStatuses.accepted;
    const rejected = ProposalStatuses.rejected;
    const finalized = ProposalStatuses.finalized;

    switch (from) {
      case pending:
        return to == negotiating || to == accepted || to == rejected;
      case negotiating:
        return to == negotiating || to == accepted || to == rejected;
      case accepted:
        return to == finalized || to == accepted;
      case rejected:
      case finalized:
        return false;
      default:
        return false;
    }
  }

  static Future<void> _logLedger({
    required String caseId,
    required String type,
    required String actorId,
    required String title,
    required String description,
    Map<String, dynamic>? metadata,
  }) {
    return EventLoggerService.logEventForActor(
      caseId: caseId,
      type: type,
      title: title,
      description: description,
      actorId: actorId,
      metadata: metadata ?? {},
    );
  }

  static Future<NegotiationProposal?> fetchProposal(String proposalId) async {
    final snap = await _proposalsCol().doc(proposalId).get();
    if (!snap.exists) return null;
    return NegotiationProposal.fromDoc(snap);
  }

  static Stream<NegotiationProposal?> watchProposal(String proposalId) {
    return _proposalsCol().doc(proposalId).snapshots().map((s) {
      if (!s.exists) return null;
      return NegotiationProposal.fromDoc(s);
    });
  }

  /// Newest first (client-sorted).
  static Stream<List<NegotiationProposal>> watchProposalsForCase(String caseId) {
    return _proposalsCol()
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map(NegotiationProposal.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  static Stream<List<ProposalMessage>> watchMessages(String proposalId) {
    return _messagesCol(proposalId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(ProposalMessage.fromDoc).toList());
  }

  /// Creates `proposals/{id}` with `kind` in `schedule` | `expense` | `location`.
  static Future<String> createProposal({
    required String caseId,
    required String childId,
    required String childName,
    required String kind,
    required String title,
    required Map<String, dynamic> originalData,
    required Map<String, dynamic> proposedData,
    required String summary,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');

    final ref = _proposalsCol().doc();
    await ref.set(<String, dynamic>{
      'caseId': caseId,
      'title': title,
      'childId': childId,
      'childName': childName,
      'kind': kind,
      'createdBy': uid,
      'status': ProposalStatuses.pending,
      'createdAt': FieldValue.serverTimestamp(),
      'originalData': originalData,
      'proposedData': proposedData,
      'summary': summary,
      'proposedRevision': 1,
    });

    try {
      await _logLedger(
        caseId: caseId,
        type: CaseEventTypes.proposalUpdated,
        actorId: uid,
        title: 'Proposal created',
        description: title,
        metadata: <String, dynamic>{
          'proposalId': ref.id,
          'kind': kind,
        },
      );
    } catch (_) {
      await ref.delete();
      rethrow;
    }

    return ref.id;
  }

  static Future<String> createScheduleProposal({
    required String caseId,
    required String childId,
    required String childName,
    required String title,
    required Map<String, dynamic> originalData,
    required Map<String, dynamic> proposedData,
    required String summary,
  }) {
    return createProposal(
      caseId: caseId,
      childId: childId,
      childName: childName,
      kind: 'schedule',
      title: title,
      originalData: originalData,
      proposedData: proposedData,
      summary: summary,
    );
  }

  static Future<void> startNegotiation(NegotiationProposal p) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    if (!canTransition(p.status, ProposalStatuses.negotiating)) {
      throw StateError('Invalid transition to negotiating');
    }

    final proposalRef = _proposalsCol().doc(p.id);
    final priorSnap = await proposalRef.get();
    final prior = priorSnap.data();
    if (prior == null) throw StateError('Proposal missing');
    final priorCopy = Map<String, dynamic>.from(prior);

    await proposalRef.update(<String, dynamic>{
      'status': ProposalStatuses.negotiating,
      'negotiatingStartedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _logLedger(
        caseId: p.caseId,
        type: CaseEventTypes.proposalUpdated,
        actorId: uid,
        title: 'Negotiation started',
        description: p.title,
        metadata: <String, dynamic>{
          'proposalId': p.id,
          'action': 'start_negotiation',
        },
      );
    } catch (_) {
      await proposalRef.set(priorCopy);
      rethrow;
    }
  }

  static Future<void> sendMessage({
    required NegotiationProposal p,
    required String text,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    if (!p.canSendMessage) {
      throw StateError('Discussion is closed for this proposal');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final msgRef = await _messagesCol(p.id).add(<String, dynamic>{
      'senderId': uid,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await _logLedger(
        caseId: p.caseId,
        type: CaseEventTypes.message,
        actorId: uid,
        title: 'Proposal message',
        description:
            trimmed.length > 200 ? '${trimmed.substring(0, 200)}…' : trimmed,
        metadata: <String, dynamic>{
          'proposalId': p.id,
          'context': 'proposal_negotiation',
          'proposalMessageId': msgRef.id,
        },
      );
    } catch (_) {
      await msgRef.delete();
      rethrow;
    }
  }

  static Future<void> updateProposedTerms({
    required NegotiationProposal p,
    required Map<String, dynamic> newProposedData,
    required String summaryNote,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    if (p.isTerminal) throw StateError('Proposal is closed');

    final nextRev = p.proposedRevision + 1;
    final proposalRef = _proposalsCol().doc(p.id);
    final priorSnap = await proposalRef.get();
    final prior = priorSnap.data();
    if (prior == null) throw StateError('Proposal missing');
    final priorCopy = Map<String, dynamic>.from(prior);

    await proposalRef.update(<String, dynamic>{
      'proposedData': newProposedData,
      'proposedRevision': nextRev,
      'summary': summaryNote.isNotEmpty ? summaryNote : p.summary,
      if (p.status == ProposalStatuses.pending)
        'status': ProposalStatuses.negotiating,
      if (p.status == ProposalStatuses.pending)
        'negotiatingStartedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _logLedger(
        caseId: p.caseId,
        type: CaseEventTypes.proposalUpdated,
        actorId: uid,
        title: 'Proposal terms updated',
        description: summaryNote.isNotEmpty ? summaryNote : p.title,
        metadata: <String, dynamic>{
          'proposalId': p.id,
          'revision': nextRev,
        },
      );
    } catch (_) {
      await proposalRef.set(priorCopy);
      rethrow;
    }
  }

  static Future<void> accept(NegotiationProposal p) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    if (!canTransition(p.status, ProposalStatuses.accepted)) {
      throw StateError('Cannot accept from status ${p.status}');
    }

    final proposalRef = _proposalsCol().doc(p.id);
    final priorSnap = await proposalRef.get();
    final prior = priorSnap.data();
    if (prior == null) throw StateError('Proposal missing');
    final priorCopy = Map<String, dynamic>.from(prior);

    await proposalRef.update(<String, dynamic>{
      'status': ProposalStatuses.accepted,
      'acceptedAt': FieldValue.serverTimestamp(),
      'acceptedBy': uid,
    });

    try {
      await _logLedger(
        caseId: p.caseId,
        type: CaseEventTypes.proposalAccepted,
        actorId: uid,
        title: 'Proposal accepted',
        description: p.title,
        metadata: <String, dynamic>{
          'proposalId': p.id,
        },
      );
    } catch (_) {
      await proposalRef.set(priorCopy);
      rethrow;
    }
  }

  static Future<void> reject(NegotiationProposal p, {String? reason}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    if (!canTransition(p.status, ProposalStatuses.rejected)) {
      throw StateError('Cannot reject from status ${p.status}');
    }

    final proposalRef = _proposalsCol().doc(p.id);
    final priorSnap = await proposalRef.get();
    final prior = priorSnap.data();
    if (prior == null) throw StateError('Proposal missing');
    final priorCopy = Map<String, dynamic>.from(prior);

    await proposalRef.update(<String, dynamic>{
      'status': ProposalStatuses.rejected,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': uid,
      if (reason != null && reason.trim().isNotEmpty) 'rejectionReason': reason.trim(),
    });

    try {
      await _logLedger(
        caseId: p.caseId,
        type: CaseEventTypes.proposalRejected,
        actorId: uid,
        title: 'Proposal rejected',
        description: reason?.trim().isNotEmpty == true ? reason!.trim() : p.title,
        metadata: <String, dynamic>{
          'proposalId': p.id,
        },
      );
    } catch (_) {
      await proposalRef.set(priorCopy);
      rethrow;
    }
  }

  static Future<void> finalizeRecord(NegotiationProposal p) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    if (!canTransition(p.status, ProposalStatuses.finalized)) {
      throw StateError('Cannot finalize from status ${p.status}');
    }

    final proposalRef = _proposalsCol().doc(p.id);
    final priorSnap = await proposalRef.get();
    final prior = priorSnap.data();
    if (prior == null) throw StateError('Proposal missing');
    final priorCopy = Map<String, dynamic>.from(prior);

    await proposalRef.update(<String, dynamic>{
      'status': ProposalStatuses.finalized,
      'finalizedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _logLedger(
        caseId: p.caseId,
        type: CaseEventTypes.proposalFinalized,
        actorId: uid,
        title: 'Proposal record finalized',
        description: p.title,
        metadata: <String, dynamic>{
          'proposalId': p.id,
        },
      );
    } catch (_) {
      await proposalRef.set(priorCopy);
      rethrow;
    }
  }
}
