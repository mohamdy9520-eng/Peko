import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class GoalCompletionChecker {
  GoalCompletionChecker._();

  static Future<void> check({
    required String goalId,
    required double newAmount,
    required Future<void> Function({
    required String goalId,
    required String goalName,
    required double targetAmount,
    }) onGoalCompleted,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final goalRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(goalId);

    final goalDoc = await goalRef.get();

    if (!goalDoc.exists) {
      debugPrint('Goal not found');
      return;
    }

    final data = goalDoc.data()!;

    final targetAmount =
        (data['targetAmount'] as num?)?.toDouble() ?? 0.0;

    final completed = data['completed'] == true;

    debugPrint("""
====== Goal Check ======
Goal ID: $goalId
Current: $newAmount
Target : $targetAmount
Completed: $completed
========================
""");

    if (!completed && newAmount >= targetAmount) {
      await onGoalCompleted(
        goalId: goalId,
        goalName: data['name'] ?? 'Goal',
        targetAmount: targetAmount,
      );
    }
  }
}