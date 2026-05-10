import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_colors.dart';

class AddIncomeScreen extends StatefulWidget {
  const AddIncomeScreen({super.key});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final List<TextEditingController> titleControllers = [];
  final List<TextEditingController> amountControllers = [];
  final List<TextEditingController> categoryControllers = [];

  @override
  void initState() {
    super.initState();
    _addNewItem();
  }

  void _addNewItem() {
    setState(() {
      titleControllers.add(TextEditingController());
      amountControllers.add(TextEditingController());
      categoryControllers.add(TextEditingController());
    });
  }

  void _removeItem(int index) {
    if (titleControllers.length == 1) return;

    setState(() {
      titleControllers[index].dispose();
      amountControllers[index].dispose();
      categoryControllers[index].dispose();

      titleControllers.removeAt(index);
      amountControllers.removeAt(index);
      categoryControllers.removeAt(index);
    });
  }

  double get _totalAmount {
    double total = 0;
    for (var c in amountControllers) {
      total += double.tryParse(c.text) ?? 0;
    }
    return total;
  }

  bool get _isValid {
    for (int i = 0; i < titleControllers.length; i++) {
      final amount = double.tryParse(amountControllers[i].text) ?? 0;

      if (titleControllers[i].text.trim().isEmpty) return false;
      if (amount <= 0) return false;
      if (categoryControllers[i].text.trim().isEmpty) return false;
    }
    return true;
  }

  Future<void> _submitAll() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields correctly'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final total = _totalAmount;

    try {
      final userRef =
      FirebaseFirestore.instance.collection('users').doc(user.uid);

      final userDoc = await userRef.get();
      final data = userDoc.data() ?? {};

      double currentBalance = (data['totalBalance'] ?? 0).toDouble();
      double currentIncome = (data['totalIncome'] ?? 0).toDouble();

      final batch = FirebaseFirestore.instance.batch();

      final transactionsRef = userRef.collection('transactions');

      for (int i = 0; i < titleControllers.length; i++) {
        final title = titleControllers[i].text.trim();
        final amount = double.parse(amountControllers[i].text);

        final categories = categoryControllers[i]
            .text
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList();

        final docRef = transactionsRef.doc();

        batch.set(docRef, {
          'title': title,
          'amount': amount,
          'type': 'income',
          'category': categories,
          'date': Timestamp.now(),
        });
      }

      batch.update(userRef, {
        'totalBalance': currentBalance + total,
        'totalIncome': currentIncome + total,
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${titleControllers.length} incomes (\$${total.toStringAsFixed(2)})',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (var c in titleControllers) c.dispose();
    for (var c in amountControllers) c.dispose();
    for (var c in categoryControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Add Income'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('Total'),
                Text(
                  '\$${_totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: titleControllers.length,
              itemBuilder: (_, i) => _buildItem(i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _submitAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size(double.infinity, 50.h),
              ),
              child: const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(int i) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: titleControllers[i],
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: amountControllers[i],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: categoryControllers[i],
              decoration: const InputDecoration(
                labelText: 'Categories (comma separated)',
                hintText: 'work, freelance, gift',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => _removeItem(i),
                icon: const Icon(Icons.delete, color: Colors.red),
              ),
            )
          ],
        ),
      ),
    );
  }
}