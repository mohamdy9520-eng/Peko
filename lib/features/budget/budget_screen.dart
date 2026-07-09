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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/di/services/ai_access_service.dart';
import '../../core/di/services/ai_service.dart';
import '../../core/di/notifications/notification_service.dart';
import '../../screens/paywall_screen.dart';
import '../../theme/app_colors.dart';
import '../../providers/currency_provider.dart';
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

  // ✅ ADDED: Store AI access info at class level so all methods can use it
  AiTier _currentAiTier = AiTier.free;
  int _remainingFreeUses = 0;

  final List<String> _incomeCategories = [
    'salary',
    'freelance',
    'investment',
    'business',
    'gift',
    'bonus',
    'other',
  ];

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

                batch.update(goalRef, {
                  'currentAmount': FieldValue.increment(amount),
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
                final actualCurrentAmount = (goalData?['currentAmount'] ?? 0).toDouble();
                final targetAmount = (goalData?['targetAmount'] ?? 0).toDouble();

                onAmountAdded(actualCurrentAmount);

                await GoalCompletionChecker.check(
                  goalId: goalId,
                  newAmount: actualCurrentAmount,
                  onGoalCompleted: _triggerGoalCompletion,
                );

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

    batch.update(goalRef, {
      'currentAmount': FieldValue.increment(amount),
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

    final freshGoalDoc = await goalRef.get();
    final actualAmount = (freshGoalDoc.data()?['currentAmount'] ?? 0).toDouble();
    final targetAmount = (freshGoalDoc.data()?['targetAmount'] ?? 0).toDouble();

    await GoalCompletionChecker.check(
      goalId: goalId,
      newAmount: actualAmount,
      onGoalCompleted: _triggerGoalCompletion,
    );

    if (actualAmount < targetAmount) {
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

    await NotificationService.sendGoalAchieved(
      goalName: goalName,
      targetAmount: targetAmount,
      currencySymbol: _currencySymbol,
    );
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
      if (mounted) setState(() => _loadingAi = false);
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
        final isAutoSaved = data['autoSaved'] == true;

        if (!isAutoSaved) {
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

  // ✅ FIXED: reserves/consumes access with proper timing, uses the result,
  // and routes to the Paywall with the real reason.
  Future<void> _showAskAIDialog() async {
    final access = await AIAccessService.peekAccess(); // للعرض بس (Badge/Snackbar)

    if (access.isBlocked) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaywallScreen(reason: access.reason),
          ),
        );
      }
      return;
    }

    _currentAiTier = access.tier;
    _remainingFreeUses = access.remainingFreeUses;

    final currentContext = context;
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (dialogCtx) => const Center(child: CircularProgressIndicator()),
    );

    await _generateAiData();

    if (mounted && Navigator.of(currentContext, rootNavigator: true).canPop()) {
      Navigator.of(currentContext, rootNavigator: true).pop();
    }
    if (!mounted) return;

    final totalIncome = (_aiResult?['totalIncome'] ?? 0).toDouble();
    if (totalIncome <= 0) {
      _showNoIncomeDialog();
      return;
    }

    // ✅ Show remaining free uses if applicable
    if (_currentAiTier == AiTier.free && _remainingFreeUses > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_remainingFreeUses free AI uses remaining'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    _openAskAIBottomSheet();
  }

  void _showNoIncomeDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: AppColors.primary),
            SizedBox(width: 12.w),
            const Text('No Income Found'),
          ],
        ),
        content: const Text(
          'Add your salary or income sources first so the AI can create a personalized plan for you!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(dialogCtx)) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (Navigator.canPop(dialogCtx)) {
                Navigator.pop(dialogCtx);
              }
              // ✅ Use WidgetsBinding to schedule after frame
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  AddIncomeDialog.show(context);
                }
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Income'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Now uses class-level variables instead of parameters
  void _openAskAIBottomSheet() {
    if (!mounted) return;

    AskAIBottomSheet.show(
      context,
      aiResult: _aiResult!,
      onPlanSelected: (planType) {
        _generateAndShowPlan(planType);
      },
    );
  }

  // ✅ FIXED: reserves the free-use slot BEFORE the paid AI call, refunds it
  // if generation fails, and always routes blocked users to the Paywall
  // with the correct reason.
  Future<void> _generateAndShowPlan(String planType) async {
    if (!mounted) return;

    // ✅ نحجز المحاولة الأول قبل أي API call مكلف
    final reserved = await AIAccessService.reserveUse();
    if (reserved.isBlocked) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PaywallScreen(reason: reserved.reason)),
        );
      }
      return;
    }
    _currentAiTier = reserved.tier;
    _remainingFreeUses = reserved.remainingFreeUses;

    BuildContext? dialogContext;
    bool dialogPopped = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        dialogContext = ctx;
        return const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('AI is analyzing your finances...')),
            ],
          ),
        );
      },
    );

    try {
      // ✅ Uses class-level _currentAiTier — determines the model inside AIService
      final plan = await AIService.generatePlan(
        tier: _currentAiTier,
        income: _aiResult!['totalIncome'],
        expense: _aiResult!['totalExpense'],
        categories: _aiResult!['expenseCategories'],
        planType: planType,
        savings: _aiResult!['savingsPotential'],
        goals: _aiResult!['goals'],
        budgets: _aiResult!['budgets'],
        languageCode: context.locale.languageCode,
        currencySymbol: _currencyProvider.getSymbol(context.locale.languageCode),
      );

      // ✅ Pop dialog FIRST before any navigation
      if (!dialogPopped && dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
        dialogPopped = true;
      }

      if (!mounted) return;

      if (plan.trim().isEmpty) {
        // ✅ رجّع المحاولة، المستخدم مأخدش حاجة
        if (_currentAiTier == AiTier.free) await AIAccessService.refundUse();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI returned empty plan')),
        );
        return;
      }

      // ✅ Navigation AFTER dialog is closed
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

      // ✅ فشل التوليد → رجّع المحاولة اللي اتحجزت
      if (_currentAiTier == AiTier.free) {
        await AIAccessService.refundUse();
      }

      // ✅ Pop dialog in catch too (once only)
      if (!dialogPopped && dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
        dialogPopped = true;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
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
                              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                              padding: EdgeInsets.zero,
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
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _showEditGoalDialog(context, docId, goal),
                              borderRadius: BorderRadius.circular(12.r),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                ],
                              ),
                            ),
                          ),

                          SizedBox(width: 8.w),

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

                          SizedBox(width: 8.w),

                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
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
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildIncomeTab(),
              _buildGoalsTab(),
            ],
          ),
          Positioned(
            right: 16.w,
            bottom: 16.h,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _tabController.index == 0
                  ? CustomFabMenu(
                key: const ValueKey('budget_fab'),
                onAskAI: _showAskAIDialog,
                onAddSavings: () => AddSavingsDialog.show(context),
                onAddIncome: () => AddIncomeDialog.show(context),
              )
                  : AddGoalFab(
                key: const ValueKey('goal_fab'),
                onPressed: () => AddGoalBottomSheet.show(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
