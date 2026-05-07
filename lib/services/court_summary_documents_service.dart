import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/court_summary_document.dart';

/// Persists custody-risk court summary PDFs to Storage and indexes metadata in
/// `users/{uid}/documents/{docId}`.
class CourtSummaryDocumentsService {
  CourtSummaryDocumentsService._();

  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  /// Latest generated court summaries for the signed-in user (max [limit]).
  static Stream<List<CourtSummaryDocument>> watchCourtSummariesForCurrentUser({
    int limit = 5,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value(const <CourtSummaryDocument>[]);
    }
    return _db
        .collection('users')
        .doc(uid)
        .collection('documents')
        .where('type', isEqualTo: 'court_summary')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(CourtSummaryDocument.fromSnapshot)
              .where((d) => d.fileUrl.isNotEmpty)
              .toList(),
        );
  }

  /// Upload [pdfBytes] and create Firestore metadata row.
  static Future<CourtSummaryDocument> saveCourtSummaryPdf({
    required Uint8List pdfBytes,
    String? caseId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final uid = user.uid;

    final docRef =
        _db.collection('users').doc(uid).collection('documents').doc();
    final docId = docRef.id;

    final storageRef =
        _storage.ref().child('users/$uid/documents/$docId.pdf');

    await storageRef.putData(
      pdfBytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          if (caseId != null) 'caseId': caseId,
          'type': 'court_summary',
        },
      ),
    );

    final fileUrl = await storageRef.getDownloadURL();

    await docRef.set(<String, dynamic>{
      'fileUrl': fileUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'court_summary',
      if (caseId != null && caseId.isNotEmpty) 'caseId': caseId,
    });

    final snap = await docRef.get();
    return CourtSummaryDocument.fromSnapshot(snap);
  }
}
