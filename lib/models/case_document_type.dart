/// Values stored in Firestore as snake_case strings.
enum CaseDocumentType {
  courtOrder('court_order'),
  agreement('agreement'),
  evidence('evidence');

  const CaseDocumentType(this.firestoreValue);
  final String firestoreValue;

  static CaseDocumentType fromFirestore(Object? raw) {
    final s = raw?.toString() ?? '';
    for (final v in CaseDocumentType.values) {
      if (v.firestoreValue == s) return v;
    }
    return CaseDocumentType.evidence;
  }

  String get label {
    switch (this) {
      case CaseDocumentType.courtOrder:
        return 'Court order';
      case CaseDocumentType.agreement:
        return 'Agreement';
      case CaseDocumentType.evidence:
        return 'Evidence';
    }
  }
}
