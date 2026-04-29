import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_role.dart';

class UserRoleService {
  UserRoleService._();

  static final _db = FirebaseFirestore.instance;

  static Future<UserRole> roleForUid(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return UserRole.fromObject(doc.data()?['role']);
  }

  static Future<UserRole> currentRole() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return UserRole.parent;
    return roleForUid(u.uid);
  }
}
