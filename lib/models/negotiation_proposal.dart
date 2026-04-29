import 'package:cloud_firestore/cloud_firestore.dart';

class ProposalStatuses {
  ProposalStatuses._();

  static const pending = 'pending';
  static const negotiating = 'negotiating';
  static const accepted = 'accepted';
  static const rejected = 'rejected';
  static const finalized = 'finalized';
}

/// Firestore: `proposals/{proposalId}` — co-parent negotiation record.
class NegotiationProposal {
  const NegotiationProposal({
    required this.id,
    required this.caseId,
    required this.title,
    required this.childId,
    required this.childName,
    required this.kind,
    required this.createdBy,
    required this.status,
    required this.createdAt,
    required this.originalData,
    required this.proposedData,
    this.summary,
    this.negotiatingStartedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.finalizedAt,
    this.acceptedBy,
    this.rejectedBy,
    this.proposedRevision = 1,
  });

  final String id;
  final String caseId;
  final String title;
  final String childId;
  final String childName;

  /// `schedule` | `expense` | `location`
  final String kind;
  final String createdBy;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> originalData;
  final Map<String, dynamic> proposedData;

  /// Denormalized text for dashboards / AI fairness.
  final String? summary;

  final DateTime? negotiatingStartedAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? finalizedAt;
  final String? acceptedBy;
  final String? rejectedBy;

  /// Increments when co-parents revise proposed terms.
  final int proposedRevision;

  static NegotiationProposal fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data() ?? {};
    final created = m['createdAt'];
    DateTime createdAt = DateTime.now();
    if (created is Timestamp) {
      createdAt = created.toDate();
    }
    DateTime? ts(dynamic v) =>
        v is Timestamp ? v.toDate() : null;

    return NegotiationProposal(
      id: doc.id,
      caseId: (m['caseId'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      childId: (m['childId'] ?? '').toString(),
      childName: (m['childName'] ?? '').toString(),
      kind: (m['kind'] ?? 'schedule').toString(),
      createdBy: (m['createdBy'] ?? '').toString(),
      status: (m['status'] ?? 'pending').toString(),
      createdAt: createdAt,
      originalData: Map<String, dynamic>.from(m['originalData'] as Map? ?? {}),
      proposedData: Map<String, dynamic>.from(m['proposedData'] as Map? ?? {}),
      summary: m['summary']?.toString(),
      negotiatingStartedAt: ts(m['negotiatingStartedAt']),
      acceptedAt: ts(m['acceptedAt']),
      rejectedAt: ts(m['rejectedAt']),
      finalizedAt: ts(m['finalizedAt']),
      acceptedBy: m['acceptedBy']?.toString(),
      rejectedBy: m['rejectedBy']?.toString(),
      proposedRevision: (m['proposedRevision'] is num)
          ? (m['proposedRevision'] as num).toInt()
          : int.tryParse('${m['proposedRevision']}') ?? 1,
    );
  }

  bool get isTerminal =>
      status == ProposalStatuses.finalized || status == ProposalStatuses.rejected;

  bool get canNegotiate =>
      status == ProposalStatuses.pending || status == ProposalStatuses.negotiating;

  bool get canAcceptOrReject =>
      status == ProposalStatuses.pending || status == ProposalStatuses.negotiating;

  bool get canFinalize => status == ProposalStatuses.accepted;

  /// New chat messages only while terms are open for discussion.
  bool get canSendMessage =>
      status == ProposalStatuses.pending ||
      status == ProposalStatuses.negotiating;
}

class ProposalMessage {
  const ProposalMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  static ProposalMessage fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data() ?? {};
    final c = m['createdAt'];
    return ProposalMessage(
      id: doc.id,
      senderId: (m['senderId'] ?? '').toString(),
      text: (m['text'] ?? '').toString(),
      createdAt: c is Timestamp ? c.toDate() : DateTime.now(),
    );
  }
}
