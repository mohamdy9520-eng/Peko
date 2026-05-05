// lib/features/home/data/repositories/transaction_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/repostories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TransactionRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  @override
  Stream<QuerySnapshot> getTransactions() {
    final userId = _currentUserId;
    if (userId == null) return Stream.empty();

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .limit(10)
        .snapshots();
  }

  @override
  Stream<QuerySnapshot> getTransactionsByDate(DateTime startDate) {
    final userId = _currentUserId;
    if (userId == null) return Stream.empty();

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('date', descending: true)
        .snapshots();
  }

  @override
  Stream<DocumentSnapshot> getUserData() {
    final userId = _currentUserId;
    if (userId == null) return Stream.empty();

    return _firestore.collection('users').doc(userId).snapshots();
  }

  @override
  Future<void> addTransaction({
    required String title,
    required double amount,
    required String type,
    required String category,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not logged in');

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .add({
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'date': Timestamp.now(),
    });

    await _updateTotals(amount, type);
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not logged in');

    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(transactionId)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    final amount = (data['amount'] ?? 0).toDouble();
    final type = data['type'] as String;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(transactionId)
        .delete();

    await _updateTotals(type == 'income' ? -amount : amount, type);
  }

  Future<void> _updateTotals(double amount, String type) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data() ?? {};

    double totalBalance = (data['totalBalance'] ?? 0).toDouble();
    double totalIncome = (data['totalIncome'] ?? 0).toDouble();
    double totalExpense = (data['totalExpense'] ?? 0).toDouble();

    if (type == 'income') {
      totalBalance += amount;
      totalIncome += amount;
    } else {
      totalBalance -= amount;
      totalExpense += amount;
    }

    await _firestore.collection('users').doc(userId).update({
      'totalBalance': totalBalance,
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
    });
  }
}