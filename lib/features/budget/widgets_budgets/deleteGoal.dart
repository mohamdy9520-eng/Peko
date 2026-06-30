import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DeleteGoal {
  static Future<void> show(
      BuildContext context, {
        required String docId,
      }) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Goal'),
          content: const Text(
            'Are you sure you want to delete this goal?\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext, rootNavigator: true).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext, rootNavigator: true).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .doc(docId)
          .delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goal deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Delete Goal Error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete goal.\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}