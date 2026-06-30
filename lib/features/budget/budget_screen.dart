import 'package:ai_expense_tracker/features/budget/widgets_budgets/FAB.dart';
import 'package:ai_expense_tracker/features/budget/widgets_budgets/addExpense.dart';
import 'package:ai_expense_tracker/features/budget/widgets_budgets/addGoal.dart';
import 'package:ai_expense_tracker/features/budget/widgets_budgets/addIncome.dart';
import 'package:ai_expense_tracker/features/budget/widgets_budgets/addSavings.dart';
import 'package:ai_expense_tracker/features/budget/widgets_budgets/ai_planType.dart';
import 'package:ai_expense_tracker/features/budget/widgets_budgets/customFabMenu.dart';
import 'package:ai_expense_tracker/features/budget/widgets_budgets/deleteBudget.dart';
import 'package:ai_expense_tracker/features/budget/widgets_budgets/deleteGoal.dart';
import 'package:ai_expense_tracker/features/budget/widgets_budgets/goal_check.dart';
import 'package:ai_expense_tracker/features/budget/widgets_budgets/income_icon.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/di/services/ai_service.dart';
import '../../core/di/notifications/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../providers/currency_provider.dart'; // <-- أضف ده
import 'dart:async';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _aiResult;
  bool _loadingAi = false;
  List<Map<String, dynamic>> _goalsList = [];

  final List<String> _incomeCategories = [
    'salary',
    'freelance',
    'investment',
    'business',
    'gift',
    'bonus',
    'other',
  ];

  // Helper method للوصول للعملة بسهولة
  CurrencyProvider get _currencyProvider => context.read<CurrencyProvider>();
  String get _currencySymbol => _currencyProvider.selectedCurrency.symbol;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadGoals();
    _initializeNotifications();
    _checkMonthlySavings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBudgetAlerts();
    });
  }

  Future<void> _checkBudgetAlerts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final oneDayAgo = Timestamp.fromDate(
        now.subtract(const Duration(hours: 24)),
      );

      final budgetsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('budgets')
          .where('active', isEqualTo: true)
          .get();

      for (var doc in budgetsSnapshot.docs) {
        final budget = doc.data();
        final budgetAmount = (budget['amount'] ?? 0).toDouble();
        final used = (budget['used'] ?? 0).toDouble();
        final percent = budgetAmount > 0 ? (used / budgetAmount).clamp(0.0, 1.0) : 0.0;
        final isOver = used > budgetAmount;
        final lastAlertAt = budget['lastAlertAt'] as Timestamp?;

        if (percent >= 0.8 && !isOver) {
          if (lastAlertAt == null || lastAlertAt.compareTo(oneDayAgo) < 0) {
            final remaining = budgetAmount - used;
            final budgetName = budget['name'] ?? 'Unnamed';

            await _sendBudgetAlert(
              docId: doc.id,
              budgetName: budgetName,
              remaining: remaining,
              budgetAmount: budgetAmount,
            );

            await doc.reference.update({
              'lastAlertAt': Timestamp.now(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking budget alerts: $e');
    }
  }

  Future<void> _sendBudgetAlert({
    required String docId,
    required String budgetName,
    required double remaining,
    required double budgetAmount,
  }) async {
    final percentUsed = ((budgetAmount - remaining) / budgetAmount * 100)
        .toStringAsFixed(0);

    final symbol = _currencySymbol;

    await NotificationService.showNotification(
      title: 'Budget Alert: $budgetName',
      body: "You've used $percentUsed% of your budget! Only $symbol${remaining.toStringAsFixed(0)} remaining.",
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ "$budgetName" is at $percentUsed%! Only $symbol${remaining.toStringAsFixed(0)} left.',
          ),
          backgroundColor: Colors.orange[800],
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'GOT IT',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _initializeNotifications() async {
    await NotificationService.initialize();
  }

  void _showEditIncomeDialog(BuildContext context, String docId, Map<String, dynamic> budget) {
    final nameController = TextEditingController(text: budget['name']);
    final amountController = TextEditingController(
      text: (budget['amount'] ?? 0).toString(),
    );
    final sourceController = TextEditingController(text: budget['source'] ?? '');

    String selectedCategory = budget['category'] ?? 'salary';
    String selectedPeriod = budget['period'] ?? 'monthly';
    DateTime? endDate = (budget['endDate'] as Timestamp?)?.toDate();

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
                      'Edit Income Source',
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
                        prefixText: '${_currencySymbol} ',
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
                        labelText: 'Source',
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
                      children: _incomeCategories.map((cat) {
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
                              color: isSelected ? Colors.green : Colors.grey[700],
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                            if (selected) setModalState(() => selectedPeriod = p);
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          label: Text(
                            p.toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : Colors.grey[700],
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
                          initialDate: endDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
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
                            ? 'Period End Date'
                            : DateFormat('MMM dd, yyyy').format(endDate!),
                        style: TextStyle(
                          color: endDate == null ? Colors.grey : Colors.black,
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
                          final amount = double.tryParse(amountController.text) ?? 0;

                          if (name.isEmpty || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill all fields')),
                            );
                            return;
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return;

                          try {
                            final budgetDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('budgets')
                                .doc(docId)
                                .get();
                            final currentUsed = (budgetDoc.data()?['used'] ?? 0).toDouble();

                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('budgets')
                                .doc(docId)
                                .update({
                              'name': name,
                              'amount': amount,
                              'remaining': amount - currentUsed,
                              'source': sourceController.text.trim(),
                              'category': selectedCategory,
                              'period': selectedPeriod,
                              'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
                              'updatedAt': Timestamp.now(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Income updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error updating income: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to update income. Please try again.')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: Text(
                          'Save Changes',
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

  void _showEditGoalDialog(BuildContext context, String docId, Map<String, dynamic> goal) {
    final nameController = TextEditingController(text: goal['name']);
    final currentController = TextEditingController(
      text: (goal['currentAmount'] ?? 0).toString(),
    );
    final targetController = TextEditingController(
      text: (goal['targetAmount'] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentAmount = double.tryParse(currentController.text) ?? 0;
          final targetAmount = double.tryParse(targetController.text) ?? 0;
          final progress = targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

          return AlertDialog(
            title: const Text('Update Goal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(
                      progress >= 1.0 ? Colors.green : Colors.amber,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% completed',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Name',
                      prefixIcon: Icon(Icons.flag),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: currentController,
                          keyboardType: TextInputType.number,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Current Amount Saved',
                            prefixText: '${_currencySymbol} ',
                            prefixIcon: const Icon(Icons.savings),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      ElevatedButton.icon(
                        onPressed: () => _showAddSavingsToGoalDialog(
                          context,
                          docId,
                          goal['name'] ?? 'Goal',
                          currentAmount,
                              (amount) {
                            setModalState(() {
                              currentController.text = amount.toString();
                            });
                          },
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target Amount',
                      prefixText: '${_currencySymbol} ',
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('goals')
                        .doc(docId)
                        .update({
                      'name': nameController.text.trim(),
                      'currentAmount': double.tryParse(currentController.text) ?? 0,
                      'targetAmount': double.tryParse(targetController.text) ?? 0,
                      'updatedAt': Timestamp.now(),
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Goal updated successfully')),
                      );
                    }
                  } catch (e) {
                    debugPrint('Error updating goal: $e');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to update goal. Please try again.')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddSavingsToGoalDialog(
      BuildContext context,
      String goalId,
      String goalName,
      double currentAmount,
      Function(double newAmount) onAmountAdded,
      ) {
    final amountController = TextEditingController();
    final nameController = TextEditingController(text: 'Extra Savings');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Savings to "$goalName"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Savings Name',
                hintText: 'e.g., Bonus, Side income',
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount to Add',
                prefixText: '${_currencySymbol} ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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

              try {
                final batch = FirebaseFirestore.instance.batch();

                final goalRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('goals')
                    .doc(goalId);

                final newAmount = currentAmount + amount;
                batch.update(goalRef, {
                  'currentAmount': newAmount,
                  'updatedAt': Timestamp.now(),
                });

                final budgetRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('budgets')
                    .doc();

                batch.set(budgetRef, {
                  'name': nameController.text.trim(),
                  'amount': amount,
                  'used': 0,
                  'remaining': amount,
                  'source': 'savings',
                  'category': 'other',
                  'period': 'one-time',
                  'isSavings': true,
                  'autoSave': false,
                  'active': true,
                  'goalId': goalId,
                  'goalName': goalName,
                  'createdAt': Timestamp.now(),
                });

                final recordRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('savings_records')
                    .doc();

                batch.set(recordRef, {
                  'amount': amount,
                  'goalId': goalId,
                  'goalName': goalName,
                  'source': 'manual_add',
                  'budgetId': budgetRef.id,
                  'budgetName': nameController.text.trim(),
                  'createdAt': Timestamp.now(),
                });

                await batch.commit();
                final goalSnapshot = await goalRef.get();
                final goalData = goalSnapshot.data();

                final targetAmount = (goalData?['targetAmount'] ?? 0).toDouble();
                await GoalCompletionChecker.check(
                  goalId: goalId,
                  newAmount: newAmount,
                  onGoalCompleted: _triggerGoalCompletion,
                );
                onAmountAdded(newAmount);

                if (newAmount >= targetAmount &&
                    (goalData?['completed'] ?? false) == false) {
                  await _triggerGoalCompletion(
                    goalId: goalId,
                    goalName: goalName,
                    targetAmount: targetAmount,
                  );
                }

                onAmountAdded(newAmount);

                if (context.mounted) {
                  Navigator.pop(context);
                  final symbol = _currencySymbol;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$symbol${amount.toStringAsFixed(0)} added to "$goalName"!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error adding savings to goal: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to add savings. Please try again.')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkMonthlySavings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final budgetsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('budgets')
        .where('active', isEqualTo: true)
        .where('autoSave', isEqualTo: true)
        .where('autoSaved', isNotEqualTo: true)
        .get();

    for (var doc in budgetsSnapshot.docs) {
      final budget = doc.data();
      final endDate = (budget['endDate'] as Timestamp?)?.toDate();
      final createdAt = (budget['createdAt'] as Timestamp?)?.toDate();
      final isPeriodEnded = endDate != null && endDate.isBefore(now);
      final is30DaysPassed = createdAt != null && now.difference(createdAt).inDays >= 30;

      if (isPeriodEnded || is30DaysPassed) {
        final budgetAmount = (budget['amount'] ?? 0).toDouble();
        final used = (budget['used'] ?? 0).toDouble();
        final remaining = budgetAmount - used;

        if (remaining > 0) {
          final savingsGoalId = budget['savingsGoalId'];

          if (savingsGoalId != null) {
            await _autoSaveToGoal(
              budgetId: doc.id,
              goalId: savingsGoalId,
              amount: remaining,
              budgetName: budget['name'] ?? 'Budget',
            );
          } else {
            await _createAutoSavingsBudget(
              budgetId: doc.id,
              amount: remaining,
              budgetName: budget['name'] ?? 'Budget',
            );
          }
        }
      }
    }
  }

  Future<void> _createAutoSavingsBudget({
    required String budgetId,
    required double amount,
    required String budgetName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final symbol = _currencySymbol;

    final savingsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('budgets')
        .doc();

    batch.set(savingsRef, {
      'name': 'Auto-Save from $budgetName',
      'amount': amount,
      'used': 0,
      'remaining': amount,
      'source': 'auto_save',
      'category': 'other',
      'period': 'one-time',
      'isSavings': true,
      'autoSave': false,
      'active': true,
      'parentBudgetId': budgetId,
      'parentBudgetName': budgetName,
      'createdAt': Timestamp.now(),
    });

    final budgetRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('budgets')
        .doc(budgetId);

    batch.update(budgetRef, {
      'active': false,
      'remaining': 0,
      'closedAt': Timestamp.now(),
      'savedAmount': amount,
      'autoSaved': true,
    });

    await batch.commit();

    await NotificationService.showNotification(
      title: 'Auto-Save Complete!',
      body: '$symbol${amount.toStringAsFixed(0)} from "$budgetName" saved automatically!',
    );
  }

  Future<void> _autoSaveToGoal({
    required String budgetId,
    required String goalId,
    required double amount,
    required String budgetName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final symbol = _currencySymbol;

    final goalRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(goalId);

    final goalDoc = await goalRef.get();
    if (!goalDoc.exists) return;

    final currentAmount = (goalDoc.data()?['currentAmount'] ?? 0).toDouble();
    final newAmount = currentAmount + amount;

    batch.update(goalRef, {
      'currentAmount': newAmount,
      'lastSavingsDate': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    final savingsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('savings')
        .doc();

    batch.set(savingsRef, {
      'amount': amount,
      'sourceBudgetId': budgetId,
      'sourceBudgetName': budgetName,
      'goalId': goalId,
      'goalName': goalDoc.data()?['name'] ?? 'Goal',
      'period': DateFormat('yyyy-MM').format(DateTime.now()),
      'createdAt': Timestamp.now(),
    });

    final budgetRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('budgets')
        .doc(budgetId);

    batch.update(budgetRef, {
      'active': false,
      'remaining': 0,
      'closedAt': Timestamp.now(),
      'savedAmount': amount,
    });

    await batch.commit();

    final targetAmount = (goalDoc.data()?['targetAmount'] ?? 0).toDouble();

    print("====== AUTO SAVE ======");
    print("Current: $currentAmount");
    print("Added  : $amount");
    print("New    : $newAmount");
    print("Target : $targetAmount");

    await GoalCompletionChecker.check(
      goalId: goalId,
      newAmount: newAmount,
      onGoalCompleted: _triggerGoalCompletion,
    );

    if (newAmount < targetAmount) {
      print("📩 Sending Monthly Notification");

      await NotificationService.showNotification(
        title: 'Monthly Savings Saved!',
        body:
        '$symbol${amount.toStringAsFixed(0)} from "$budgetName" saved to "${goalDoc.data()?['name']}"!',
      );
    }
  }

  Future<void> _triggerGoalCompletion({
    required String goalId,
    required String goalName,
    required double targetAmount,
  }) async {
    print("🔥 _triggerGoalCompletion START");

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(goalId)
        .update({
      'completed': true,
      'completedAt': Timestamp.now(),
    });

    print("🔥 Sending Goal Notification");

    final symbol = _currencySymbol;

    await NotificationService.showNotification(
      title: 'Goal Achieved! 🎉',
      body:
      'You\'ve reached $symbol${targetAmount.toStringAsFixed(0)} for "$goalName"!',
    );

    print("🔥 Goal Notification Sent");
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _goalsList = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    });
  }

  Stream<QuerySnapshot> getBudgets() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('budgets')
        .where('active', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getGoals() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _generateAiData() async {
    setState(() => _loadingAi = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingAi = false);
      return;
    }

    try {
      QuerySnapshot budgetsSnapshot;
      try {
        budgetsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('budgets')
            .where('active', isEqualTo: true)
            .get();
      } catch (e) {
        debugPrint('Error fetching budgets: $e');
        budgetsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('budgets')
            .get();
      }

      double totalIncome = 0;
      double totalUsed = 0;

      for (var doc in budgetsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final isSavings = data['isSavings'] == true;
        final isAutoSaved = data['autoSaved'] == true;

        if (!isSavings && !isAutoSaved) {
          totalIncome += (data['amount'] ?? 0).toDouble();
          totalUsed += (data['used'] ?? 0).toDouble();
        }
      }

      QuerySnapshot transactionsSnapshot;
      try {
        transactionsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .where('type', isEqualTo: 'expense')
            .get();
      } catch (e) {
        debugPrint('Error fetching transactions: $e');
        transactionsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .get();
      }

      double totalExpense = 0;
      Map<String, double> expenseCategories = {};

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final amount = (data['amount'] ?? 0).toDouble();
        totalExpense += amount;

        final category = data['category'] ?? 'other';
        if (category is String) {
          expenseCategories[category] = (expenseCategories[category] ?? 0) + amount;
        } else if (category is List) {
          for (var c in category) {
            if (c != null) {
              expenseCategories[c.toString()] = (expenseCategories[c.toString()] ?? 0) + amount;
            }
          }
        }
      }

      final remaining = totalIncome - totalUsed;
      final savingsPotential = remaining > 0 ? remaining : 0;

      if (!mounted) return;

      setState(() {
        _aiResult = {
          "totalIncome": totalIncome,
          "totalExpense": totalExpense,
          "totalUsed": totalUsed,
          "remaining": remaining,
          "savingsPotential": savingsPotential,
          "expenseCategories": expenseCategories,
          "goals": _goalsList,
          "budgets": budgetsSnapshot.docs.map((d) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            return {
              'id': d.id,
              ...data,
            };
          }).toList(),
        };
        _loadingAi = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error generating AI data: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _loadingAi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error loading financial data. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showAskAIDialog() {
    if (_aiResult == null) {
      _generateAiData().then((_) {
        if (!mounted) return;
        if (_aiResult != null) {
          AskAIBottomSheet.show(
            context,
            aiResult: _aiResult!,
            onPlanSelected: (planType) {
              _generateAndShowPlan(planType);
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load financial data. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }).catchError((e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return;
    }
    AskAIBottomSheet.show(
      context,
      aiResult: _aiResult!,
      onPlanSelected: (planType) {
        _generateAndShowPlan(planType);
      },
    );
  }

  Widget _buildPlanOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
    );
  }

  Future<void> _generateAndShowPlan(String planType) async {
    try {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(
                child: Text('AI is analyzing your finances...'),
              ),
            ],
          ),
        ),
      );

      final plan = await AIService.generatePlan(
        income: _aiResult!['totalIncome'],
        expense: _aiResult!['totalExpense'],
        categories: _aiResult!['expenseCategories'],
        planType: planType,
        savings: _aiResult!['savingsPotential'],
        goals: _aiResult!['goals'],
        budgets: _aiResult!['budgets'],
      );

      if (!mounted) return;

      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();

      if (plan.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI returned empty plan'),
          ),
        );
        return;
      }

      context.push(
        '/ai-result',
        extra: {
          'plan': plan,
          'planType': planType,
          'goals': _goalsList,
          'onSaveToGoal': _setupAutoSave,
        },
      );
    } catch (e) {
      debugPrint('AI ERROR: $e');

      if (!mounted) return;

      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  }

  Future<void> _setupAutoSave({
    required String budgetId,
    required String goalId,
    required double percentage,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('budgets')
        .doc(budgetId)
        .update({
      'autoSave': true,
      'savingsGoalId': goalId,
      'savePercentage': percentage,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-save setup: ${percentage.toStringAsFixed(0)}% to goal!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildIncomeTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: getBudgets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60.sp, color: Colors.red[300]),
                SizedBox(height: 16.h),
                Text(
                  'Error loading income',
                  style: TextStyle(fontSize: 16.sp, color: Colors.red[400]),
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final budgets = snapshot.data?.docs ?? [];

        if (budgets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 80.sp, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No income sources yet',
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap "+" to add your salary!',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await _checkBudgetAlerts();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final budget = budgets[index].data() as Map<String, dynamic>;
              final docId = budgets[index].id;

              final budgetAmount = (budget['amount'] ?? 0).toDouble();
              final used = (budget['used'] ?? 0).toDouble();
              final remaining = budgetAmount - used;
              final percent = budgetAmount > 0 ? (used / budgetAmount).clamp(0.0, 1.0) : 0.0;
              final isOver = used > budgetAmount;

              final budgetName = budget['name'] ?? 'Unnamed';
              final source = budget['source'] ?? '';
              final rawCategory = budget['category'];
              String category = 'other';
              if (rawCategory is List && rawCategory.isNotEmpty) {
                category = rawCategory.first.toString();
              } else if (rawCategory is String) {
                category = rawCategory;
              }
              final autoSave = budget['autoSave'] ?? false;
              final endDate = (budget['endDate'] as Timestamp?)?.toDate();
              final isSavings = budget['isSavings'] ?? false;
              final linkedGoalId = budget['goalId'];
              final linkedGoalName = budget['goalName'];
              final isAutoSaved = budget['autoSaved'] ?? false;

              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  side: autoSave
                      ? const BorderSide(color: Colors.green, width: 2)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () => _showEditIncomeDialog(context, docId, budget),
                  borderRadius: BorderRadius.circular(16.r),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSavings
                                    ? Colors.teal.withOpacity(0.1)
                                    : AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: IncomeCategoryIcon(
                                category: category,
                                isSavings: isSavings,
                                color: isSavings ? Colors.teal : AppColors.primary,
                                size: 24.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          budgetName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16.sp,
                                          ),
                                        ),
                                      ),
                                      if (isSavings)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: Colors.teal,
                                            borderRadius: BorderRadius.circular(6.r),
                                          ),
                                          child: Text(
                                            'SAVINGS',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (linkedGoalId != null) ...[
                                        SizedBox(width: 6.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius: BorderRadius.circular(6.r),
                                          ),
                                          child: Text(
                                            linkedGoalName ?? 'GOAL',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (isAutoSaved) ...[
                                        SizedBox(width: 6.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: Colors.purple,
                                            borderRadius: BorderRadius.circular(6.r),
                                          ),
                                          child: Text(
                                            'AUTO-SAVED',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '$source • ${category.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (autoSave)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  'AUTO-SAVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _showEditIncomeDialog(context, docId, budget);
                                    break;
                                  case 'add_expense':
                                    AddExpenseDialog.show(
                                      context,
                                      budgetId: docId,
                                      budgetName: budgetName,
                                    );
                                    break;
                                  case 'delete':
                                    DeleteBudget.show(context, docId: docId);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8.w),
                                      const Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'add_expense',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.remove_circle, color: Colors.orange),
                                      SizedBox(width: 8.w),
                                      const Text('Add Expense'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8.w),
                                      const Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(
                              isOver ? Colors.red : AppColors.primary,
                            ),
                            minHeight: 8.h,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_currencySymbol}${used.toStringAsFixed(0)} used',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOver
                                  ? 'Over by ${_currencySymbol}${(-remaining).toStringAsFixed(0)}!'
                                  : '${_currencySymbol}${remaining.toStringAsFixed(0)} left',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: isOver ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        if (endDate != null) ...[
                          SizedBox(height: 8.h),
                          Text(
                            'Period ends: ${DateFormat('MMM dd').format(endDate)}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                        if (autoSave && remaining > 0) ...[
                          SizedBox(height: 8.h),
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.savings, size: 16.sp, color: Colors.green),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        '${_currencySymbol}${remaining.toStringAsFixed(0)} will auto-save when period ends',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (budget['savingsGoalId'] != null) ...[
                                  SizedBox(height: 4.h),
                                  Row(
                                    children: [
                                      Icon(Icons.flag, size: 14.sp, color: Colors.amber),
                                      SizedBox(width: 8.w),
                                      Text(
                                        'Will go to: ${budget['savingsGoalName'] ?? 'Goal'}',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (isAutoSaved && budget['parentBudgetName'] != null) ...[
                          SizedBox(height: 8.h),
                          Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: Colors.purple.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome, size: 16.sp, color: Colors.purple),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    'Auto-saved from: ${budget['parentBudgetName']}',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.purple[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGoalsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: getGoals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final goals = snapshot.data?.docs ?? [];

        if (goals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_outlined, size: 80, color: Colors.grey[300]),
                SizedBox(height: 16.h),
                Text(
                  'No goals yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Set your first savings goal!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
                SizedBox(height: 24.h),
                ElevatedButton.icon(
                  onPressed: () => AddGoalBottomSheet.show(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Your First Goal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index].data() as Map<String, dynamic>;
              final docId = goals[index].id;

              final targetAmount = (goal['targetAmount'] ?? 0).toDouble();
              final currentAmount = (goal['currentAmount'] ?? 0).toDouble();
              final goalName = goal['name'] ?? 'Unnamed Goal';
              final deadline = goal['deadline'] as Timestamp?;
              final completed = goal['completed'] ?? false;
              final percent = targetAmount > 0
                  ? (currentAmount / targetAmount).clamp(0.0, 1.0)
                  : 0.0;

              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  side: completed
                      ? const BorderSide(color: Colors.green, width: 2)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () => _showEditGoalDialog(context, docId, goal),
                  borderRadius: BorderRadius.circular(16.r),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: completed
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                completed ? Icons.check_circle : Icons.flag,
                                color: completed ? Colors.green : Colors.amber,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goalName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                  if (deadline != null)
                                    Text(
                                      "Target: ${DateFormat('MMM dd, yyyy').format(deadline.toDate())}",
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (completed)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  'COMPLETED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                await Future.delayed(const Duration(milliseconds: 150));

                                if (!context.mounted) return;

                                if (value == 'delete') {
                                  await DeleteGoal.show(
                                    context,
                                    docId: docId,
                                  );
                                }

                                if (value == 'edit') {
                                  _showEditGoalDialog(
                                    context,
                                    docId,
                                    goal,
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit, color: Colors.blue),
                                      SizedBox(width: 8.w),
                                      const Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8.w),
                                      const Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        LinearProgressIndicator(
                          value: percent,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                            completed ? Colors.green : Colors.amber,
                          ),
                          minHeight: 8.h,
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_currencySymbol}${currentAmount.toStringAsFixed(0)} saved',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_currencySymbol}${targetAmount.toStringAsFixed(0)} target',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Budgets'),
            Tab(icon: Icon(Icons.flag), text: 'Goals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIncomeTab(),
          _buildGoalsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? SingleChildScrollView(
        reverse: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomFabMenu(
              onAskAI: _showAskAIDialog,
              onAddSavings: () => AddSavingsDialog.show(context),
              onAddIncome: () => AddIncomeDialog.show(context),
            ),
          ],
        ),
      )
          : AddGoalFab(
        onPressed: () => AddGoalBottomSheet.show(context),
      ),
    );
  }
}