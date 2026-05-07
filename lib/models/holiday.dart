import 'package:cloud_firestore/cloud_firestore.dart';

/// Case-scoped holiday custody override: `cases/{caseId}/holidays/{id}`.
class Holiday {
  const Holiday({
    required this.id,
    required this.caseId,
    required this.name,
    required this.dateLocal,
    required this.assignedParentId,
    this.notes,
    this.isOverride = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String caseId;
  final String name;

  /// Local calendar date (time ignored).
  final DateTime dateLocal;
  final String assignedParentId;
  final String? notes;
  final bool isOverride;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static String dateKeyFor(DateTime localDay) =>
      '${localDay.year.toString().padLeft(4, '0')}-'
      '${localDay.month.toString().padLeft(2, '0')}-'
      '${localDay.day.toString().padLeft(2, '0')}';

  factory Holiday.fromFirestore(String id, Map<String, dynamic> data) {
    final caseId = (data['caseId'] ?? '').toString();
    final name = (data['name'] ?? '').toString();
    final assignedParentId = (data['assignedParentId'] ?? '').toString();
    final notes = data['notes']?.toString();
    final isOverride = data['isOverride'] == true;
    DateTime dateLocal;
    final dk = data['dateKey']?.toString();
    if (dk != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dk)) {
      final p = dk.split('-');
      dateLocal = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } else {
      final ts = data['date'];
      if (ts is Timestamp) {
        final t = ts.toDate();
        dateLocal = DateTime(t.year, t.month, t.day);
      } else {
        dateLocal = DateTime.now();
      }
    }
    DateTime? createdAt;
    final c = data['createdAt'];
    if (c is Timestamp) createdAt = c.toDate();
    DateTime? updatedAt;
    final u = data['updatedAt'];
    if (u is Timestamp) updatedAt = u.toDate();

    return Holiday(
      id: id,
      caseId: caseId,
      name: name.isNotEmpty ? name : 'Holiday',
      dateLocal: dateLocal,
      assignedParentId: assignedParentId,
      notes: notes,
      isOverride: isOverride,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore({bool isCreate = false}) {
    final key = dateKeyFor(dateLocal);
    final midnight = DateTime(dateLocal.year, dateLocal.month, dateLocal.day);
    return <String, dynamic>{
      'caseId': caseId,
      'name': name,
      'date': Timestamp.fromDate(midnight),
      'dateKey': key,
      'assignedParentId': assignedParentId,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'isOverride': isOverride,
      if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
