/// Case library document category (Firestore snake_case values).
enum CaseDocumentCategory {
  courtOrder('court_order'),
  filing('filing'),
  evidence('evidence'),
  agreement('agreement');

  const CaseDocumentCategory(this.firestoreValue);
  final String firestoreValue;

  static CaseDocumentCategory fromFirestore(Object? raw) {
    final s = raw?.toString() ?? '';
    for (final v in CaseDocumentCategory.values) {
      if (v.firestoreValue == s) return v;
    }
    return CaseDocumentCategory.evidence;
  }

  String get label {
    switch (this) {
      case CaseDocumentCategory.courtOrder:
        return 'Court order';
      case CaseDocumentCategory.filing:
        return 'Filing';
      case CaseDocumentCategory.evidence:
        return 'Evidence';
      case CaseDocumentCategory.agreement:
        return 'Agreement';
    }
  }

  bool get isCourtOrder => this == CaseDocumentCategory.courtOrder;
}
