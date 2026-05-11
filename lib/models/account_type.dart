/// Persisted on `users/{uid}` as [firestoreValue] alongside `role`.
enum AccountType {
  parent('parent'),
  attorney('attorney');

  const AccountType(this.firestoreValue);

  final String firestoreValue;

  static AccountType? tryParse(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim().toLowerCase();
    if (s == 'attorney') return AccountType.attorney;
    if (s == 'parent') return AccountType.parent;
    return null;
  }
}
