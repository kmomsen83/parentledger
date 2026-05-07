import 'package:cloud_firestore/cloud_firestore.dart';

/// Metadata for generated court summary PDFs under
/// `users/{userId}/documents/{docId}`.
class CourtSummaryDocument {
  final String id;
  final String fileUrl;
  final DateTime? createdAt;
  final String type;

  const CourtSummaryDocument({
    required this.id,
    required this.fileUrl,
    this.createdAt,
    required this.type,
  });

  factory CourtSummaryDocument.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return CourtSummaryDocument(
        id: doc.id,
        fileUrl: '',
        createdAt: null,
        type: '',
      );
    }
    final ts = data['createdAt'];
    DateTime? created;
    if (ts is Timestamp) created = ts.toDate();
    return CourtSummaryDocument(
      id: doc.id,
      fileUrl: (data['fileUrl'] ?? '').toString(),
      createdAt: created,
      type: (data['type'] ?? '').toString(),
    );
  }
}
