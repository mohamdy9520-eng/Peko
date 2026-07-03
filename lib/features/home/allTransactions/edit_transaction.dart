import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditTransactionScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditTransactionScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState
    extends State<EditTransactionScreen> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;

  bool _isSaving = false;

  String _type = 'expense';
  String _category = 'other';

  // ✅ القائمة المعتمدة
  static const List<String> _validCategories = [
    'food',
    'shopping',
    'transport',
    'bills',
    'health',
    'entertainment',
    'work',
    'other',
  ];

  @override
  void initState() {
    super.initState();

    _titleController =
        TextEditingController(text: widget.data['title'] ?? '');

    _amountController =
        TextEditingController(
          text: (widget.data['amount'] ?? 0).toString(),
        );

    _type = widget.data['type']?.toString() ?? 'expense';

    final categoryData = widget.data['category'];

    if (categoryData is List && categoryData.isNotEmpty) {
      _category = categoryData.first.toString();
    } else {
      _category = categoryData?.toString() ?? 'other';
    }

    // ✅ التحقق: إذا الفئة مش في القائمة، خليها 'other'
    if (!_validCategories.contains(_category)) {
      _category = 'other';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title is required'),
        ),
      );
      return;
    }

    final amount =
    double.tryParse(_amountController.text.trim());

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid amount'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final oldAmount = (widget.data['amount'] ?? 0).toDouble();
      final oldType = widget.data['type']?.toString() ?? 'expense';
      final newAmount = amount;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(widget.docId)
          .update({
        'title': _titleController.text.trim(),
        'amount': newAmount,
        'type': _type,
        'category': _category,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (oldAmount != newAmount || oldType != _type) {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();
        final userData = userDoc.data() ?? {};

        double currentBalance = (userData['totalBalance'] ?? 0).toDouble();
        double currentIncome = (userData['totalIncome'] ?? 0).toDouble();
        double currentExpense = (userData['totalExpense'] ?? 0).toDouble();

        if (oldType == 'income') {
          currentBalance -= oldAmount;
          currentIncome -= oldAmount;
        } else {
          currentBalance += oldAmount;
          currentExpense -= oldAmount;
        }

        if (_type == 'income') {
          currentBalance += newAmount;
          currentIncome += newAmount;
        } else {
          currentBalance -= newAmount;
          currentExpense += newAmount;
        }

        await userDocRef.update({
          'totalBalance': currentBalance,
          'totalIncome': currentIncome,
          'totalExpense': currentExpense,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction updated'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _amountController,
              keyboardType:
              const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'income',
                  child: Text('Income'),
                ),
                DropdownMenuItem(
                  value: 'expense',
                  child: Text('Expense'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _validCategories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(
                    cat[0].toUpperCase() + cat.substring(1),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed:
                _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text(
                  'Save Changes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}