/// Response payload from [EventLoggerService.logCaseEventForActorWithResult].
class CaseLedgerWriteResult {
  const CaseLedgerWriteResult({
    required this.eventId,
    required this.hash,
    required this.previousHash,
  });

  final String eventId;
  final String hash;
  final String previousHash;

  factory CaseLedgerWriteResult.fromCallableData(dynamic data) {
    final map = Map<Object?, Object?>.from(data as Map);
    return CaseLedgerWriteResult(
      eventId: map['eventId']?.toString() ?? '',
      hash: map['hash']?.toString() ?? '',
      previousHash: map['previousHash']?.toString() ?? '',
    );
  }
}
