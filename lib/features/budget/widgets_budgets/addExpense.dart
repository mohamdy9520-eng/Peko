import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart';

class AddExpenseDialog {
  static Future<void> show(
      BuildContext context, {
        required String budgetId,
        required String budgetName,
      }) async {
    final amountController = TextEditingController();
    final descController = TextEditingController();

    final List<String> expenseCategories = [
      'food', 'shopping', 'transport', 'bills',
      'entertainment', 'health', 'education', 'other'
    ];

    String selectedCategory = 'food';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Expense from $budgetName',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g., Lunch, Uber, etc.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Category',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: expenseCategories.map((cat) {
                        final isSelected = selectedCategory == cat;
                        return ChoiceChip(
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedCategory = cat);
                            }
                          },
                          selectedColor: Colors.red.withOpacity(0.2),
                          label: Text(
                            cat.toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.red : Colors.grey[700],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final amount = double.tryParse(amountController.text) ?? 0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter valid amount')),
                            );
                            return;
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return;

                          final batch = FirebaseFirestore.instance.batch();

                          final budgetRef = FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('budgets')
                              .doc(budgetId);

                          final budgetDoc = await budgetRef.get();
                          final budgetData = budgetDoc.data() ?? {};
                          final budgetAmount = (budgetData['amount'] ?? 0).toDouble();
                          final currentUsed = (budgetData['used'] ?? 0).toDouble();
                          final newUsed = currentUsed + amount;
                          final newRemaining = budgetAmount - newUsed;

                          // CRITICAL FIX: Update BOTH used AND remaining
                          batch.update(budgetRef, {
                            'used': newUsed,
                            'remaining': newRemaining, // WAS MISSING!
                          });

                          final transRef = FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('transactions')
                              .doc();

                          batch.set(transRef, {
                            'type': 'expense',
                            'amount': amount,
                            'category': selectedCategory,
                            'budgetId': budgetId,
                            'budgetName': budgetName,
                            'description': descController.text.trim(),
                            'date': Timestamp.now(),
                            'createdAt': Timestamp.now(),
                          });

                          await batch.commit();

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('-\$${amount.toStringAsFixed(0)} from $budgetName'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.remove_circle),
                        label: const Text('Add Expense'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}