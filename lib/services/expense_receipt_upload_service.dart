import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads expense receipt images to Firebase Storage (case-scoped path matches [storage.rules]).
class ExpenseReceiptUploadService {
  ExpenseReceiptUploadService._();

  /// Returns download URL or `null` on failure.
  ///
  /// Path: `cases/{caseId}/receipts/{expenseId}.jpg`
  static Future<String?> uploadReceipt({
    required File file,
    required String caseId,
    required String expenseId,
  }) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('cases')
          .child(caseId)
          .child('receipts')
          .child('$expenseId.jpg');
      await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }
}
