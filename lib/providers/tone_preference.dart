import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/tone_models.dart';

const _prefsKey = 'ux_tone';

/// Selected copy tone (neutral / professional / legal).
///
/// Persisted locally and on `users/{uid}.uxTone` when signed in.
class TonePreference extends ChangeNotifier {
  TonePreference() {
    _restore();
  }

  UiTone _tone = UiTone.neutral;
  UiTone get tone => _tone;

  String? _lastRemoteApplied;

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final parsed = parseUiTone(p.getString(_prefsKey));
      if (parsed != null && parsed != _tone) {
        _tone = parsed;
        notifyListeners();
      }
    } catch (_) {}
  }

  void hydrateFromFirestore(String? remote) {
    if (remote == null || remote.isEmpty) return;
    if (remote == _lastRemoteApplied) return;
    _lastRemoteApplied = remote;
    final parsed = parseUiTone(remote);
    if (parsed == null) return;
    if (parsed == _tone) return;
    _tone = parsed;
    notifyListeners();
    SharedPreferences.getInstance().then((p) {
      p.setString(_prefsKey, _tone.storageName);
    });
  }

  Future<void> setTone(UiTone value) async {
    if (value == _tone) return;
    _tone = value;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, _tone.storageName);
    } catch (_) {}

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {'uxTone': _tone.storageName},
          SetOptions(merge: true),
        );
      } catch (_) {}
    }
  }
}
