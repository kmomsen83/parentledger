import 'package:cloud_firestore/cloud_firestore.dart';

/// `cases/{caseId}/holiday_proposals/{id}`
class HolidayProposal {
  const HolidayProposal({
    required this.id,
    required this.caseId,
    required this.holidayId,
    required this.proposedBy,
    required this.targetParentId,
    required this.newParentId,
    required this.message,
    required this.status,
    this.startTime,
    this.endTime,
    this.createdAt,
  });

  final String id;
  final String caseId;
  final String holidayId;
  final String proposedBy;
  final String targetParentId;
  final String newParentId;
  final String message;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? createdAt;

  static const pending = 'pending';
  static const accepted = 'accepted';
  static const denied = 'denied';

  factory HolidayProposal.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? st;
    final s = data['startTime'];
    if (s is Timestamp) st = s.toDate();
    DateTime? en;
    final e = data['endTime'];
    if (e is Timestamp) en = e.toDate();
    DateTime? createdAt;
    final c = data['createdAt'];
    if (c is Timestamp) createdAt = c.toDate();

    return HolidayProposal(
      id: id,
      caseId: (data['caseId'] ?? '').toString(),
      holidayId: (data['holidayId'] ?? '').toString(),
      proposedBy: (data['proposedBy'] ?? '').toString(),
      targetParentId: (data['targetParentId'] ?? '').toString(),
      newParentId: (data['newParentId'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      status: (data['status'] ?? pending).toString(),
      startTime: st,
      endTime: en,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'caseId': caseId,
      'holidayId': holidayId,
      'proposedBy': proposedBy,
      'targetParentId': targetParentId,
      'newParentId': newParentId,
      'message': message,
      'status': status,
      if (startTime != null) 'startTime': Timestamp.fromDate(startTime!),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime!),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
