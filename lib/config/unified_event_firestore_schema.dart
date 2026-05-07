/// Canonical `case_events/{eventId}` ledger shape (append-only; writes via Cloud Functions).
library;

const Map<String, dynamic> kUnifiedCaseEventLedgerFields = {
  'caseId': 'string',
  'type': 'string',
  'actorId': 'string',
  'actorName': 'string',
  'title': 'string',
  'description': 'string',
  'timestamp': 'timestamp',
  'timestampMillis': 'number',
  'data': 'map',
  'metadata': 'map',
  'hash': 'string',
  'previousHash': 'string',
  'signature': 'string?',
  'createdAt': 'timestamp',
};

/// Embed inside `data` / `metadata` for cross-entity linkage (no orphan rows).
const List<String> kRelatedIdKeys = [
  'relatedIds',
  'linkedMessageIds',
  'linkedExchangeIds',
  'linkedExpenseIds',
];
