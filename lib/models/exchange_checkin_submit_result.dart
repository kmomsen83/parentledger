/// Returned after an immutable check-in is written.
class ExchangeCheckinSubmitResult {
  const ExchangeCheckinSubmitResult({
    required this.checkInId,
    required this.contentHash,
    required this.recordedAddress,
    required this.deviceTimestamp,
    this.arrivalTiming,
    this.minutesFromScheduled,
  });

  final String checkInId;
  final String contentHash;
  final String recordedAddress;
  final DateTime deviceTimestamp;
  final String? arrivalTiming;
  final int? minutesFromScheduled;
}
