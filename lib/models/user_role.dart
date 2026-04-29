/// Stored in `users/{uid}` as field `role` (default: parent).
enum UserRole {
  parent,
  attorney;

  static UserRole fromObject(Object? raw) {
    if (raw == null) return UserRole.parent;
    final s = raw.toString().toLowerCase().trim();
    if (s == 'attorney') return UserRole.attorney;
    return UserRole.parent;
  }

  bool get isAttorney => this == UserRole.attorney;
}
