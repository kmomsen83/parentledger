import 'package:cloud_firestore/cloud_firestore.dart';

class ChildModel {
  final String id;
  final String name;
  final DateTime? dob;
  final String gender;

  final String? school;
  final String? grade;
  final String? activities;
  final String? medicalNotes;
  final String? photoUrl;

  /// Private uploader-only photos (Firestore `users/{uid}/childPrivate/{id}`) — not on shared case doc.
  final List<String> childPhotoUrls;

  /// Uploader uid when [childPhotoUrls] are populated (always self for private uploads).
  final String? uploadedByUid;

  final DateTime? createdAt;

  /// 🔥 NOT STORED IN FIRESTORE (UI ONLY)
  final String? caseId;

  ChildModel({
    required this.id,
    required this.name,
    this.dob,
    required this.gender,
    this.school,
    this.grade,
    this.activities,
    this.medicalNotes,
    this.photoUrl,
    this.childPhotoUrls = const [],
    this.uploadedByUid,
    this.createdAt,
    this.caseId,
  });

  /// 🔥 FROM FIRESTORE DOC
  factory ChildModel.fromDoc(
    DocumentSnapshot doc, {
    String? caseId,
  }) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return ChildModel(
      id: doc.id,
      name: data["name"] ?? "",
      dob: _parseDate(data["dob"]),
      gender: data["gender"] ?? "Unknown",
      school: _stringField(data["school"]),
      grade: _stringField(data["grade"]),
      activities: _activitiesField(data["activities"]),
      medicalNotes: _stringField(data["medicalNotes"]),
      photoUrl: data["photoUrl"],
      childPhotoUrls: _stringListField(data["childPhotoUrls"]),
      uploadedByUid: _stringField(data["uploadedByUid"]),
      createdAt: _parseDate(data["createdAt"]),
      caseId: caseId,
    );
  }

  /// 🔥 FROM MAP (SERVICE SAFE)
  factory ChildModel.fromMap(
    String id,
    Map<String, dynamic> data, {
    String? caseId,
  }) {
    return ChildModel(
      id: id,
      name: data["name"] ?? "",
      dob: _parseDate(data["dob"]),
      gender: data["gender"] ?? "Unknown",
      school: _stringField(data["school"]),
      grade: _stringField(data["grade"]),
      activities: _activitiesField(data["activities"]),
      medicalNotes: _stringField(data["medicalNotes"]),
      photoUrl: data["photoUrl"],
      childPhotoUrls: _stringListField(data["childPhotoUrls"]),
      uploadedByUid: _stringField(data["uploadedByUid"]),
      createdAt: _parseDate(data["createdAt"]),
      caseId: caseId,
    );
  }

  static List<String> _stringListField(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String? _stringField(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Activities may be stored as a string or a list of strings.
  static String? _activitiesField(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
    }
    return value.toString();
  }

  /// 🔥 SAFE DATE PARSER (prevents crashes)
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  /// 🔥 COMPUTED AGE (NEVER STORE AGE)
  int? get age {
    if (dob == null) return null;

    final now = DateTime.now();
    int years = now.year - dob!.year;

    if (now.month < dob!.month ||
        (now.month == dob!.month && now.day < dob!.day)) {
      years--;
    }

    return years;
  }

  /// 🔥 CLEAN DISPLAY (UI READY)
  String get displayAge {
    final a = age;
    if (a == null) return "";
    return "$a yrs";
  }

  /// 🔥 INITIALS (for avatar fallback)
  String get initials {
    if (name.isEmpty) return "?";

    final parts = name.trim().split(" ");
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// 🔥 HAS PHOTO
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  /// 🔥 TO FIRESTORE
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      "name": name,
      "gender": gender,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    /// Only set createdAt once
    if (createdAt == null) {
      map["createdAt"] = FieldValue.serverTimestamp();
    } else {
      map["createdAt"] = Timestamp.fromDate(createdAt!);
    }

    if (dob != null) map["dob"] = Timestamp.fromDate(dob!);
    if (school != null) map["school"] = school;
    if (grade != null) map["grade"] = grade;
    if (activities != null) map["activities"] = activities;
    if (medicalNotes != null) map["medicalNotes"] = medicalNotes;
    if (photoUrl != null) map["photoUrl"] = photoUrl;

    return map;
  }

  /// 🔥 COPY WITH (STATE SAFE)
  ChildModel copyWith({
    String? name,
    DateTime? dob,
    String? gender,
    String? school,
    String? grade,
    String? activities,
    String? medicalNotes,
    String? photoUrl,
    List<String>? childPhotoUrls,
    String? uploadedByUid,
    DateTime? createdAt,
    String? caseId,
  }) {
    return ChildModel(
      id: id,
      name: name ?? this.name,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      school: school ?? this.school,
      grade: grade ?? this.grade,
      activities: activities ?? this.activities,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      photoUrl: photoUrl ?? this.photoUrl,
      childPhotoUrls: childPhotoUrls ?? this.childPhotoUrls,
      uploadedByUid: uploadedByUid ?? this.uploadedByUid,
      createdAt: createdAt ?? this.createdAt,
      caseId: caseId ?? this.caseId,
    );
  }
}
