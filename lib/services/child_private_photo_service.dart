import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'image_compress_util.dart';

/// Child photos visible only to the uploading parent — not stored on shared case docs.
///
/// Firestore: `users/{uid}/childPrivate/{childId}` with `photoUrls`, `uploadedByUid`.
/// Storage: `users/{uid}/children/{childId}/photos/{photoId}.jpg`.
abstract final class ChildPrivatePhotoService {
  static const _uuid = Uuid();

  static DocumentReference<Map<String, dynamic>> _privateDoc(
    String uid,
    String childId,
  ) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('childPrivate')
          .doc(childId);

  /// Primary photo for list UI (first private URL), if any.
  static Stream<String?> watchPrimaryPhotoUrl({
    required String uid,
    required String childId,
  }) {
    return _privateDoc(uid, childId).snapshots().map((s) {
      if (!s.exists) return null;
      final urls = s.data()?['photoUrls'];
      if (urls is! List || urls.isEmpty) return null;
      final first = urls.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
      return first?.toString();
    });
  }

  /// All private URLs for the signed-in parent (ordered).
  static Stream<List<String>> watchPhotoUrls({
    required String uid,
    required String childId,
  }) {
    return _privateDoc(uid, childId).snapshots().map((s) {
      if (!s.exists) return const <String>[];
      final urls = s.data()?['photoUrls'];
      if (urls is! List) return const <String>[];
      return urls
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    });
  }

  static Future<String> uploadPhoto({
    required String childId,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Not signed in');

    final uid = user.uid;
    final photoId = '${_uuid.v4()}.jpg';
    final storagePath = 'users/$uid/children/$childId/photos/$photoId';
    final ref = FirebaseStorage.instance.ref(storagePath);

    final compressed = await ImageCompressUtil.compressToJpeg(file);
    final task = ref.putFile(
      compressed,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    task.snapshotEvents.listen((e) {
      if (e.totalBytes > 0) {
        onProgress?.call(e.bytesTransferred / e.totalBytes);
      }
    });
    await task;
    final url = await ref.getDownloadURL();

    final doc = _privateDoc(uid, childId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final list = <String>[];
      if (snap.exists) {
        final raw = snap.data()?['photoUrls'];
        if (raw is List) {
          for (final e in raw) {
            final s = e.toString().trim();
            if (s.isNotEmpty) list.add(s);
          }
        }
      }
      list.insert(0, url);
      tx.set(
        doc,
        {
          'photoUrls': list,
          'uploadedByUid': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    if (kDebugMode) {
      debugPrint('[ChildPrivatePhotoService] uploaded private child photo');
    }
    return url;
  }

  /// Removes one URL from Firestore and deletes the storage object when path matches our prefix.
  static Future<void> deletePhotoAtUrl({
    required String childId,
    required String downloadUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final doc = _privateDoc(uid, childId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(doc);
      if (!snap.exists) return;
      final raw = snap.data()?['photoUrls'];
      if (raw is! List) return;
      final list = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      list.removeWhere((e) => e == downloadUrl);
      tx.set(
        doc,
        {
          'photoUrls': list,
          'uploadedByUid': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    try {
      await FirebaseStorage.instance.refFromURL(downloadUrl).delete();
    } catch (_) {}
  }

  /// Deletes all private photos for [childId] (e.g. child removed from case).
  static Future<void> deleteAllForChild(String childId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final snap = await _privateDoc(uid, childId).get();
    if (!snap.exists) return;
    final raw = snap.data()?['photoUrls'];
    if (raw is List) {
      for (final e in raw) {
        final url = e.toString().trim();
        if (url.isEmpty) continue;
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }
    }
    await _privateDoc(uid, childId).delete();
  }
}
