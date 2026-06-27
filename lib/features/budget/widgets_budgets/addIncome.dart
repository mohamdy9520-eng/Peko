import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/di/constants/app_lists.dart';
import '../../../theme/app_colors.dart';

class AddIncomeDialog {static Future<void> show(BuildContext context) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final sourceController = TextEditingController();

    String selectedCategory = 'salary';
    String selectedPeriod = 'monthly';
    DateTime? endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setModalState) {
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
                          'Add Income Source',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 24.h),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Income Name',
                            hintText: 'e.g., Monthly Salary, Freelance Project',
                            prefixIcon: const Icon(Icons.label_outline),
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
                        TextField(
                          controller: sourceController,
                          decoration: InputDecoration(
                            labelText: 'Source / Company',
                            hintText: 'e.g., Google, Upwork',
                            prefixIcon: const Icon(Icons.source_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Income Type',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: AppLists.incomeCategories.map((cat) {
                            final isSelected = selectedCategory == cat;
                            return FilterChip(
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() => selectedCategory = cat);
                                }
                              },
                              selectedColor: Colors.green.withOpacity(0.2),
                              checkmarkColor: Colors.green,
                              label: Text(
                                cat.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: isSelected ? Colors.green : Colors
                                      .grey[700],
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Period',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 8.w,
                          children: ['monthly', 'weekly', 'one-time'].map((p) {
                            final isSelected = selectedPeriod == p;
                            return ChoiceChip(
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) setModalState(() =>
                                selectedPeriod = p);
                              },
                              selectedColor: AppColors.primary.withOpacity(0.2),
                              label: Text(
                                p.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? AppColors.primary : Colors
                                      .grey[700],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 16.h),
                        ListTile(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(
                                  const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(
                                  days: 365 * 10)), // FIXED: Dynamic
                            );
                            if (picked != null) {
                              setModalState(() => endDate = picked);
                            }
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          leading: const Icon(Icons.calendar_today),
                          title: Text(
                            endDate == null
                                ? 'Period End Date (Optional)'
                                : DateFormat('MMM dd, yyyy').format(endDate!),
                            style: TextStyle(
                              color: endDate == null ? Colors.grey : Colors
                                  .black,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
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
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .collection('budgets')
                                    .add({
                                  'name': name,
                                  'amount': amount,
                                  'financialType': 'income',
                                  'used': 0,
                                  'remaining': amount,
                                  'source': sourceController.text.trim(),
                                  'category': selectedCategory,
                                  'period': selectedPeriod,
                                  'endDate': endDate != null ? Timestamp
                                      .fromDate(endDate!) : null,
                                  'autoSave': false,
                                  'active': true,
                                  'createdAt': Timestamp.now(),
                                });

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Income added successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error adding income: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text(
                                        'Failed to add income. Please try again.')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: Text(
                              'Add Income',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
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