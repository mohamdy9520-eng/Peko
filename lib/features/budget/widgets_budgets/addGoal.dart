import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/currency_provider.dart';

class AddGoalBottomSheet {
  static Future<void> show(BuildContext context) async {
    final nameController = TextEditingController();
    final targetController = TextEditingController();

    DateTime? deadline;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (statefulContext, setModalState) {
            final currencyProvider = statefulContext.watch<CurrencyProvider>();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(statefulContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24.r),
                  ),
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
                        'Add New Goal',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 24.h),

                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Goal Name',
                          hintText: 'e.g. Buy a Car',
                          prefixIcon: const Icon(Icons.flag_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),

                      SizedBox(height: 16.h),

                      TextField(
                        controller: targetController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Target Amount',
                          hintText: '0.00',
                          prefixText: '${currencyProvider.symbol} ',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),

                      SizedBox(height: 16.h),

                      ListTile(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: statefulContext,
                            initialDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                          );

                          if (picked != null) {
                            setModalState(() {
                              deadline = picked;
                            });
                          }
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide(
                            color: Colors.grey[300]!,
                          ),
                        ),
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          deadline == null
                              ? 'Select Deadline'
                              : DateFormat(
                            'MMM dd, yyyy',
                          ).format(deadline!),
                          style: TextStyle(
                            color: deadline == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16.sp,
                        ),
                      ),

                      SizedBox(height: 24.h),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: Text(
                            'Add Goal',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: 16.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          onPressed: () async {
                            final name = nameController.text.trim();

                            final target =
                                double.tryParse(
                                  targetController.text,
                                ) ??
                                    0;

                            if (name.isEmpty || target <= 0) {
                              ScaffoldMessenger.of(statefulContext)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please fill all fields',
                                  ),
                                ),
                              );
                              return;
                            }

                            final user =
                                FirebaseAuth.instance.currentUser;

                            if (user == null) return;

                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('goals')
                                  .add({
                                'name': name,
                                'targetAmount': target,
                                'currentAmount': 0,
                                'deadline': deadline != null
                                    ? Timestamp.fromDate(
                                  deadline!,
                                )
                                    : null,
                                'completed': false,
                                'createdAt': Timestamp.now(),
                                'updatedAt': Timestamp.now(),
                              });

                              if (bottomSheetContext.mounted) {
                                Navigator.pop(bottomSheetContext);
                              }

                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Goal ${currencyProvider.formatAmountCompact(target)} added successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint(
                                'Error adding goal: $e',
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to add goal. Please try again.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),

                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}