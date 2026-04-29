import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/case_document_type.dart';
import '../models/case_event.dart';
import 'crashlytics_service.dart';
import 'event_logger_service.dart';

/// `cases/{caseId}/documents/{docId}` with files in Storage.
class CaseDocumentService {
  CaseDocumentService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> documentsCol(String caseId) =>
      _db.collection('cases').doc(caseId).collection('documents');

  static Reference _storageRef(String caseId, String docId, String fileName) =>
      FirebaseStorage.instance
          .ref()
          .child('cases')
          .child(caseId)
          .child('documents')
          .child(docId)
          .child(fileName);

  static Future<String> uploadDocument({
    required String caseId,
    required File file,
    required String fileName,
    required CaseDocumentType type,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final docRef = documentsCol(caseId).doc();
    final docId = docRef.id;
    final safeName = fileName.replaceAll(RegExp(r'[/\\]'), '_');
    final storageRef = _storageRef(caseId, docId, safeName);

    await storageRef.putFile(file);
    final fileUrl = await storageRef.getDownloadURL();

    await docRef.set(<String, dynamic>{
      'fileUrl': fileUrl,
      'fileName': safeName,
      'uploadedBy': user.uid,
      'uploadedAt': FieldValue.serverTimestamp(),
      'type': type.firestoreValue,
    });

    try {
      await EventLoggerService.logEventForActor(
        caseId: caseId,
        type: CaseEventTypes.statusChange,
        title: 'Document uploaded',
        description: safeName,
        actorId: user.uid,
        metadata: <String, dynamic>{
          'documentId': docId,
          'fileName': safeName,
          'documentType': type.firestoreValue,
          'title': safeName,
          'status': 'uploaded',
        },
      );
    } catch (e, st) {
      await docRef.delete();
      try {
        await storageRef.delete();
      } catch (_) {}
      await CrashlyticsService.recordError(e, st, reason: 'document ledger rollback');
      rethrow;
    }

    return docId;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchDocuments(
    String caseId,
  ) =>
      documentsCol(caseId)
          .orderBy('uploadedAt', descending: true)
          .snapshots();
}
