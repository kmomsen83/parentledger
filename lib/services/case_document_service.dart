import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/case_document_category.dart';
import '../models/case_event.dart';
import '../models/user_role.dart';
import 'counsel_access_policy.dart';
import 'crashlytics_service.dart';
import 'event_logger_service.dart';
import 'notification_service.dart';

/// `cases/{caseId}/documents/{docId}` with files under Storage `cases/{caseId}/documents/...`.
///
/// Immutability: core fields are written once; only lifecycle flags may update (rules-enforced).
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

  static Future<String> _resolveUploaderRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'parent';
    final snap = await _db.collection('users').doc(uid).get();
    final role = UserRole.fromObject(snap.data()?['role']);
    return role.isAttorney ? 'attorney' : 'parent';
  }

  /// Upload a PDF or image; [category] and [title] are required for the court-ready library.
  static Future<String> uploadDocument({
    required String caseId,
    required File file,
    required String fileName,
    required CaseDocumentCategory category,
    required String title,
    String? notes,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final uploaderRole = await _resolveUploaderRole();
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) throw ArgumentError('Title is required');

    if (uploaderRole == 'attorney') {
      final len = await file.length();
      if (CounselAccessPolicy.fileExceedsAttorneyLimit(len)) {
        throw const CounselUploadLimitException();
      }
    }

    final docRef = documentsCol(caseId).doc();
    final docId = docRef.id;
    final safeName = fileName.replaceAll(RegExp(r'[/\\]'), '_');
    final storageRef = _storageRef(caseId, docId, safeName);

    await storageRef.putFile(file);
    final fileUrl = await storageRef.getDownloadURL();

    final noteStr = notes?.trim() ?? '';
    final payload = <String, dynamic>{
      'caseId': caseId,
      'fileUrl': fileUrl,
      'fileName': safeName,
      'title': trimmedTitle,
      'uploadedBy': user.uid,
      'uploaderRole': uploaderRole,
      'category': category.firestoreValue,
      'immutable': true,
      'createdAt': FieldValue.serverTimestamp(),
      'uploadedAt': FieldValue.serverTimestamp(),
      'superseded': false,
      'deleted': false,
      if (noteStr.isNotEmpty) 'notes': noteStr,
    };

    await docRef.set(payload);

    try {
      await EventLoggerService.logEventForActor(
        caseId: caseId,
        type: CaseEventTypes.statusChange,
        title: 'Document uploaded',
        description: trimmedTitle,
        actorId: user.uid,
        metadata: <String, dynamic>{
          'documentId': docId,
          'fileName': safeName,
          'category': category.firestoreValue,
          'title': trimmedTitle,
          'uploaderRole': uploaderRole,
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

    try {
      await NotificationService.notifyCounselDocumentUploaded(
        caseId: caseId,
        title: trimmedTitle,
        excludeUploaderUid:
            uploaderRole == 'attorney' ? user.uid : null,
      );
    } catch (e, st) {
      await CrashlyticsService.recordError(
        e,
        st,
        reason: 'notifyCounselDocument',
      );
    }

    return docId;
  }

  /// Marks a document superseded (immutable metadata unchanged).
  static Future<void> markSuperseded({
    required String caseId,
    required String documentId,
    String? supersededByDocId,
  }) async {
    final ref = documentsCol(caseId).doc(documentId);
    await ref.update(<String, dynamic>{
      'superseded': true,
      'supersededAt': FieldValue.serverTimestamp(),
      if (supersededByDocId != null) 'supersededByDocId': supersededByDocId,
    });
  }

  /// Soft-delete: hidden from default list; record retained for audit.
  static Future<void> markDeleted({
    required String caseId,
    required String documentId,
  }) async {
    final ref = documentsCol(caseId).doc(documentId);
    await ref.update(<String, dynamic>{
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchDocuments(
    String caseId,
  ) =>
      documentsCol(caseId)
          .orderBy('uploadedAt', descending: true)
          .snapshots();

  /// Display name cache for uploader ids (best-effort).
  static Future<Map<String, String>> loadUploaderNames(Iterable<String> uids) async {
    final out = <String, String>{};
    for (final uid in uids.toSet()) {
      final snap = await _db.collection('users').doc(uid).get();
      final d = snap.data();
      final dn = (d?['displayName'] ?? '').toString().trim();
      if (dn.isNotEmpty) {
        out[uid] = dn;
        continue;
      }
      final fn = (d?['firstName'] ?? '').toString().trim();
      final ln = (d?['lastName'] ?? '').toString().trim();
      final full = '$fn $ln'.trim();
      out[uid] = full.isNotEmpty ? full : uid;
    }
    return out;
  }
}
