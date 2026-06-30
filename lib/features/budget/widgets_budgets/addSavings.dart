import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AddSavingsDialog {
  static Future<void> show(BuildContext context) async {
    final nameController = TextEditingController(text: 'My Savings');
    final amountController = TextEditingController();
    String? selectedGoalId;
    String? selectedGoalName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setModalState) {
              final user = FirebaseAuth.instance.currentUser;

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery
                      .of(context)
                      .viewInsets
                      .bottom,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24.r)),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          'Add Savings',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 24.h),

                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Name',
                            hintText: 'e.g., Emergency Fund, Vacation Savings',
                            prefixIcon: const Icon(Icons.savings_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        SizedBox(height: 16.h),

                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            hintText: '0.00',
                            prefixText: '\$ ',
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        SizedBox(height: 16.h),

                        StreamBuilder<QuerySnapshot>(
                          stream: user != null
                              ? FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('goals')
                              .where('completed', isEqualTo: false)
                              .orderBy('createdAt', descending: true)
                              .snapshots()
                              : null,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data!.docs
                                .isEmpty) {
                              return Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Colors.grey[600]),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        'No active goals. Create a goal first!',
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final goals = snapshot.data!.docs;
                            final goalIds = goals.map((g) => g.id).toSet();

                            final String? dropdownValue =
                            goalIds.contains(selectedGoalId) ? selectedGoalId : null;

                            return DropdownButtonFormField<String>(
                              value: dropdownValue,
                              hint: const Text('Select a goal (optional)'),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Link to Goal (Optional)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: goals.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(data['name'] ?? 'Unnamed Goal'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setModalState(() {
                                  selectedGoalId = value;

                                  if (value != null) {
                                    final goalDoc = goals.firstWhere((g) => g.id == value);
                                    selectedGoalName =
                                    (goalDoc.data() as Map<String, dynamic>)['name'];
                                  } else {
                                    selectedGoalName = null;
                                  }
                                });
                              },
                            );
                          },
                        ),
                        SizedBox(height: 24.h),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              final amount = double.tryParse(
                                  amountController.text) ?? 0;

                              if (name.isEmpty || amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Please fill all fields')),
                                );
                                return;
                              }

                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return;

                              try {
                                final batch = FirebaseFirestore.instance
                                    .batch();

                                // 1. Create savings budget
                                final savingsRef = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('budgets')
                                    .doc();

                                batch.set(savingsRef, {
                                  'name': name,
                                  'amount': amount,
                                  'used': 0,
                                  'remaining': amount,
                                  'source': 'savings',
                                  'category': 'other',
                                  'period': 'one-time',
                                  'isSavings': true,
                                  'autoSave': false,
                                  'active': true,
                                  'goalId': selectedGoalId,
                                  'goalName': selectedGoalName,
                                  'createdAt': Timestamp.now(),
                                });

                                // 2. If linked to goal, update goal currentAmount
                                if (selectedGoalId != null) {
                                  final goalRef = FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('goals')
                                      .doc(selectedGoalId);

                                  final goalDoc = await goalRef.get();

                                  // FIXED: Check if goal exists before proceeding
                                  if (!goalDoc.exists) {
                                    if (context.mounted) {
                                      ScaffoldMessenger
                                          .of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Selected goal no longer exists. Please choose another.'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  final currentAmount = (goalDoc
                                      .data()?['currentAmount'] ?? 0)
                                      .toDouble();
                                  final targetAmount = (goalDoc
                                      .data()?['targetAmount'] ?? 0).toDouble();
                                  final newAmount = currentAmount + amount;

                                  batch.update(goalRef, {
                                    'currentAmount': newAmount,
                                    'updatedAt': Timestamp.now(),
                                  });

                                  // Check if goal completed
                                  if (newAmount >= targetAmount) {
                                    batch.update(goalRef, {
                                      'completed': true,
                                      'completedAt': Timestamp.now(),
                                    });
                                  }

                                  // Create savings record
                                  final savingsRecordRef = FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('savings_records')
                                      .doc();

                                  batch.set(savingsRecordRef, {
                                    'amount': amount,
                                    'goalId': selectedGoalId,
                                    'goalName': selectedGoalName,
                                    'source': 'manual',
                                    'budgetId': savingsRef.id,
                                    'budgetName': name,
                                    'createdAt': Timestamp.now(),
                                  });
                                }

                                await batch.commit();

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        selectedGoalId != null
                                            ? '\$${amount.toStringAsFixed(
                                            0)} added to "$selectedGoalName"!'
                                            : 'Savings added successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error adding savings: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text(
                                        'Failed to add savings. Please try again.')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.savings),
                            label: Text(
                              'Add Savings',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
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