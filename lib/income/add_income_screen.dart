import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final List<String> selectedCategories = [];

  final List<String> categories = ['work', 'freelance', 'investment', 'gift', 'other'];
  final List<IconData> categoryIcons = [
    Icons.work,
    Icons.laptop,
    Icons.trending_up,
    Icons.card_giftcard,
    Icons.more_horiz
  ];

  @override
  void initState() {
    super.initState();
    _addNewItem();
  }

  void _addNewItem() {
    setState(() {
      titleControllers.add(TextEditingController());
      amountControllers.add(TextEditingController());
      selectedCategories.add(categories[0]);
    });
  }

  void _removeItem(int index) {
    if (titleControllers.length == 1) return;
    setState(() {
      titleControllers[index].dispose();
      amountControllers[index].dispose();
      titleControllers.removeAt(index);
      amountControllers.removeAt(index);
      selectedCategories.removeAt(index);
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
      if (titleControllers[i].text.trim().isEmpty) return false;
      if ((double.tryParse(amountControllers[i].text) ?? 0) <= 0) return false;
    }
    return titleControllers.isNotEmpty;
  }

  Future<void> _submitAll() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please fill all fields correctly'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final total = _totalAmount;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() ?? {};
      double currentBalance = (data['totalBalance'] ?? 0).toDouble();
      double currentIncome = (data['totalIncome'] ?? 0).toDouble();

      // ✅ تسجيل Transaction واحد بالإجمالي
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .add({
        'title': 'Multiple Income (${titleControllers.length} sources)',
        'amount': total,
        'type': 'income',
        'category': 'multiple',
        'itemCount': titleControllers.length,
        'date': Timestamp.now(),
      });

      // ✅ تحديث الرصيد
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'totalBalance': currentBalance + total,
        'totalIncome': currentIncome + total,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Added ${titleControllers.length} incomes (\$${total.toStringAsFixed(2)})'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    for (var c in titleControllers) c.dispose();
    for (var c in amountControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text('Add Income', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: AppColors.primary.withOpacity(0.1),
            child: Column(
              children: [
                const Text('Total Amount',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '\$ ${_totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.income,
                  ),
                ),
                Text('${titleControllers.length} item(s)',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: titleControllers.length,
              itemBuilder: (context, index) => _buildItemCard(index),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: _addNewItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Income'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _submitAll,
                  icon: const Icon(Icons.check),
                  label: const Text('Submit All', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.income,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: titleControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Item ${index + 1} Name',
                      prefixIcon: const Icon(Icons.label_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: amountControllers[index],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: selectedCategories[index],
                    isExpanded: true, // ✅ مهم عشان الـ overflow
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: List.generate(categories.length, (i) {
                      return DropdownMenuItem(
                        value: categories[i],
                        child: Row(
                          mainAxisSize: MainAxisSize.min, // ✅ مهم
                          children: [
                            Icon(categoryIcons[i],
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Flexible( // ✅ مهم عشان الـ overflow
                              child: Text(
                                categories[i].toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    onChanged: (value) {
                      setState(() => selectedCategories[index] = value!);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}