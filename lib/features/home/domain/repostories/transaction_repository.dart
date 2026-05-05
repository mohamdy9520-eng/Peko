// lib/features/home/domain/repositories/transaction_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class TransactionRepository {
  Stream<QuerySnapshot> getTransactions();
  Stream<QuerySnapshot> getTransactionsByDate(DateTime startDate);
  Stream<DocumentSnapshot> getUserData();

  Future<void> addTransaction({
    required String title,
    required double amount,
    required String type,
    required String category,
  });

  Future<void> deleteTransaction(String transactionId);
}