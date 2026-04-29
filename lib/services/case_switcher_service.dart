import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttorneyCaseItem {
  const AttorneyCaseItem({
    required this.caseId,
    required this.linkedAt,
  });

  final String caseId;
  final DateTime? linkedAt;
}

class CaseSwitcherService extends ChangeNotifier {
  static const String _selectedCaseKey = 'attorney_selected_case_id';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _casesSub;

  List<AttorneyCaseItem> _cases = const [];
  String? _selectedCaseId;
  bool _ready = false;

  List<AttorneyCaseItem> get cases => _cases;
  String? get selectedCaseId => _selectedCaseId;
  bool get ready => _ready;
  bool get hasMultipleCases => _cases.length > 1;

  void start() {
    // Background session listener — not duplicated with a [StreamBuilder] on the same stream.
    _authSub ??= _auth.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    await _casesSub?.cancel();
    _casesSub = null;
    _cases = const [];
    _selectedCaseId = null;
    _ready = false;
    notifyListeners();

    if (user == null) {
      _ready = true;
      notifyListeners();
      return;
    }

    final persisted = await _readPersistedCaseId();
    // Attorney multi-case list — single subscription on [ChangeNotifier], not UI [StreamBuilder].
    _casesSub = _db
        .collection('users')
        .doc(user.uid)
        .collection('cases')
        .orderBy('linkedAt', descending: true)
        .snapshots()
        .listen((snap) async {
      final loaded = snap.docs.map((d) {
        final data = d.data();
        final caseId = (data['caseId'] ?? d.id).toString();
        final ts = data['linkedAt'];
        return AttorneyCaseItem(
          caseId: caseId,
          linkedAt: ts is Timestamp ? ts.toDate() : null,
        );
      }).toList();
      _cases = loaded;

      final candidate = _selectedCaseId ?? persisted;
      if (candidate != null && loaded.any((c) => c.caseId == candidate)) {
        _selectedCaseId = candidate;
      } else {
        _selectedCaseId = loaded.isNotEmpty ? loaded.first.caseId : null;
      }

      _ready = true;
      notifyListeners();
      await _persistSelectedCaseId(_selectedCaseId);
    });
  }

  Future<void> selectCase(String caseId) async {
    if (_selectedCaseId == caseId) return;
    _selectedCaseId = caseId;
    notifyListeners();
    await _persistSelectedCaseId(caseId);
  }

  Future<void> _persistSelectedCaseId(String? caseId) async {
    final prefs = await SharedPreferences.getInstance();
    if (caseId == null || caseId.isEmpty) {
      await prefs.remove(_selectedCaseKey);
      return;
    }
    await prefs.setString(_selectedCaseKey, caseId);
  }

  Future<String?> _readPersistedCaseId() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_selectedCaseKey)?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _casesSub?.cancel();
    super.dispose();
  }
}
