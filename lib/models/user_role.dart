/// Stored in `users/{uid}` as field `role` (default: parent).
///
/// Future multi-role: prefer additive fields (e.g. `roles[]`, `primaryRole`)
/// rather than overloading this enum alone.
enum UserRole {
  parent,
  attorney;

  static UserRole fromObject(Object? raw) {
    if (raw == null) return UserRole.parent;
    final s = raw.toString().toLowerCase().trim();
    if (s == 'attorney') return UserRole.attorney;
    return UserRole.parent;
  }

  /// Prefer explicit `role`, then `accountType` (client merges can briefly skew).
  static UserRole fromUserData(Map<String, dynamic>? data) {
    if (data == null) return UserRole.parent;
    final fromRole = fromObject(data['role']);
    if (fromRole == UserRole.attorney) return UserRole.attorney;
    final at = (data['accountType'] ?? '').toString().trim().toLowerCase();
    if (at == 'attorney') return UserRole.attorney;
    return UserRole.parent;
  }

  bool get isAttorney => this == UserRole.attorney;
}
