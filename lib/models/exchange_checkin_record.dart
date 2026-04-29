/// Verification outcome for an exchange check-in (court audit trail).
enum ExchangeCheckinVerificationStatus {
  verified,
  partial,
  failed;

  String get firestoreValue => name;
}
