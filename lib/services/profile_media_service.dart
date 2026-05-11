import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'image_compress_util.dart';

/// Owner-only profile / attorney logo storage: `users/{uid}/profile/avatar.jpg`.
abstract final class ProfileMediaService {
  static Reference _ref(String uid) =>
      FirebaseStorage.instance.ref('users/$uid/profile/avatar.jpg');

  /// Uploads JPEG, updates [profilePhotoUrl] and legacy [photoUrl] on `users/{uid}`.
  static Future<String> uploadAvatarJpeg(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }

    final compressed = await ImageCompressUtil.compressToJpeg(file);
    final ref = _ref(user.uid);

    final task = ref.putFile(
      compressed,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      ),
    );

    task.snapshotEvents.listen((e) {
      if (e.totalBytes > 0) {
        onProgress?.call(e.bytesTransferred / e.totalBytes);
      }
    });

    await task;
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'profilePhotoUrl': url,
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (kDebugMode) {
      debugPrint('[ProfileMediaService] avatar uploaded');
    }
    return url;
  }

  static Future<void> deleteAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _ref(user.uid).delete();
    } catch (_) {}
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'profilePhotoUrl': FieldValue.delete(),
        'photoUrl': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
  }
}
