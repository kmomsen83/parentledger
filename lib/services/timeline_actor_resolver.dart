import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_role.dart';

/// Display info for timeline actors (no raw UIDs in UI).
class TimelineActor {
  const TimelineActor({
    required this.uid,
    required this.fullName,
    required this.roleLabel,
  });

  final String uid;
  final String fullName;
  /// Father / Mother / Attorney / Parent
  final String roleLabel;

  static String _nameFromUserDoc(Map<String, dynamic>? d) {
    if (d == null) return '';
    final dn = (d['displayName'] ?? '').toString().trim();
    if (dn.isNotEmpty) return dn;
    final fn = (d['firstName'] ?? '').toString().trim();
    final ln = (d['lastName'] ?? '').toString().trim();
    final full = '$fn $ln'.trim();
    if (full.isNotEmpty) return full;
    final em = (d['email'] ?? '').toString().trim();
    if (em.isNotEmpty) return em.split('@').first;
    return '';
  }

  static String _roleLabelFromUserDoc(Map<String, dynamic>? d) {
    final role = UserRole.fromObject(d?['role']);
    if (role == UserRole.attorney) return 'Attorney';

    final pt = (d?['parentType'] ?? '').toString().toLowerCase().trim();
    if (pt == 'mom') return 'Mother';
    if (pt == 'dad') return 'Father';
    if (pt == 'guardian') return 'Guardian';

    final g = (d?['gender'] ?? '').toString().toLowerCase().trim();
    if (g == 'male' || g == 'm') return 'Father';
    if (g == 'female' || g == 'f') return 'Mother';
    return 'Parent';
  }

  static Future<TimelineActor> load(String uid) async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final d = snap.data();
    var name = _nameFromUserDoc(d);
    if (name.isEmpty) name = 'Participant';
    return TimelineActor(
      uid: uid,
      fullName: name,
      roleLabel: _roleLabelFromUserDoc(d),
    );
  }

  /// Loads all [uids] in parallel; missing docs still yield a stable label.
  static Future<Map<String, TimelineActor>> loadMany(Iterable<String> uids) async {
    final unique = uids.toSet().where((u) => u.isNotEmpty).toList();
    final out = <String, TimelineActor>{};
    await Future.wait(unique.map((uid) async {
      out[uid] = await load(uid);
    }));
    return out;
  }
}
