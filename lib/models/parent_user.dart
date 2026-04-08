class ParentUser {
final String id;
final String email;
final String displayName;
final String role; // parent / lawyer / mediator / grandparent
final String caseId;
final bool soloMode;
final DateTime createdAt;

ParentUser({
required this.id,
required this.email,
required this.displayName,
required this.role,
required this.caseId,
required this.soloMode,
required this.createdAt,
});

factory ParentUser.fromMap(Map<String, dynamic> map, String id) {
return ParentUser(
id: id,
email: map['email'] ?? '',
displayName: map['displayName'] ?? '',
role: map['role'] ?? 'parent',
caseId: map['caseId'] ?? '',
soloMode: map['soloMode'] ?? true,
createdAt: DateTime.parse(map['createdAt']),
);
}

Map<String, dynamic> toMap() {
return {
'email': email,
'displayName': displayName,
'role': role,
'caseId': caseId,
'soloMode': soloMode,
'createdAt': createdAt.toIso8601String(),
};
}
}
