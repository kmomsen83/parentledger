import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuidedOnboardingState {
  const GuidedOnboardingState({
    required this.isFirstTimeUser,
    required this.onboardingCompleted,
    required this.messagesCount,
    required this.expensesCount,
    required this.exchangesCount,
  });

  final bool isFirstTimeUser;
  final bool onboardingCompleted;
  final int messagesCount;
  final int expensesCount;
  final int exchangesCount;

  bool get messageDone => messagesCount > 0;
  bool get expenseDone => expensesCount > 0;
  bool get scheduleDone => exchangesCount > 0;
  int get completedActions =>
      (messageDone ? 1 : 0) + (expenseDone ? 1 : 0) + (scheduleDone ? 1 : 0);
}

class GuidedOnboardingService {
  GuidedOnboardingService._();

  static const _kFirstTime = 'guided_first_time_user_v1';
  static const _kCompleted = 'guided_onboarding_completed_v1';

  static Future<GuidedOnboardingState> load(String caseId) async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final userRef = user == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userSnap = userRef == null ? null : await userRef.get();
    final userData = userSnap?.data() ?? <String, dynamic>{};

    final msgCount = await _count(
      FirebaseFirestore.instance
          .collection('cases')
          .doc(caseId)
          .collection('conversations')
          .doc('primary')
          .collection('messages'),
    );
    final expenseCount = await _count(
      FirebaseFirestore.instance
          .collection('cases')
          .doc(caseId)
          .collection('expenses'),
    );
    final exchangeCount = await _count(
      FirebaseFirestore.instance
          .collection('cases')
          .doc(caseId)
          .collection('exchanges'),
    );

    final inferredFirstTime =
        msgCount == 0 && expenseCount == 0 && exchangeCount == 0;
    final persistedFirst =
        userData['isFirstTimeUser'] == true || prefs.getBool(_kFirstTime) == true;
    final isFirstTimeUser = inferredFirstTime || persistedFirst;

    final allDone = msgCount > 0 && expenseCount > 0 && exchangeCount > 0;
    final persistedCompleted = userData['onboardingCompleted'] == true ||
        prefs.getBool(_kCompleted) == true;
    final onboardingCompleted = allDone || persistedCompleted;

    await prefs.setBool(_kFirstTime, isFirstTimeUser);
    await prefs.setBool(_kCompleted, onboardingCompleted);
    if (userRef != null) {
      await userRef.set({
        'isFirstTimeUser': isFirstTimeUser,
        'onboardingCompleted': onboardingCompleted,
      }, SetOptions(merge: true));
    }

    return GuidedOnboardingState(
      isFirstTimeUser: isFirstTimeUser,
      onboardingCompleted: onboardingCompleted,
      messagesCount: msgCount,
      expensesCount: expenseCount,
      exchangesCount: exchangeCount,
    );
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCompleted, true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'onboardingCompleted': true,
      }, SetOptions(merge: true));
    }
  }

  static Future<int> _count(CollectionReference<Map<String, dynamic>> col) async {
    try {
      final snap = await col.limit(1).get();
      if (snap.docs.isEmpty) return 0;
      final agg = await col.count().get();
      return agg.count ?? snap.docs.length;
    } catch (_) {
      final fallback = await col.limit(500).get();
      return fallback.docs.length;
    }
  }
}

