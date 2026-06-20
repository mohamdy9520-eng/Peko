import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/di/services/ai_service.dart';
import '../../core/di/services/notification_service.dart';
import '../../theme/app_colors.dart';
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

  // INCOME CATEGORIES (not spending categories!)
  final List<String> _incomeCategories = [
    'salary',
    'freelance',
    'investment',
    'business',
    'gift',
    'bonus',
    'other',
  ];

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
  }

  Future<void> _initializeNotifications() async {
    await NotificationService.initialize();
  }

  void _showAddGoalDialog(BuildContext context) {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    DateTime? deadline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (statefulContext, setModalState) {
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
                        hintText: 'e.g., Buy a Car, Vacation',
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

                    ListTile(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: statefulContext,
                          initialDate:
                          DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );

                        if (picked != null) {
                          setModalState(() {
                            deadline = picked;
                          });
                        }
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        deadline == null
                            ? 'Select Deadline'
                            : DateFormat('MMM dd, yyyy').format(deadline!),
                        style: TextStyle(
                          color:
                          deadline == null ? Colors.grey : Colors.black,
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
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final target =
                              double.tryParse(targetController.text) ?? 0;

                          if (name.isEmpty || target <= 0) {
                            ScaffoldMessenger.of(statefulContext).showSnackBar(
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
                                  ? Timestamp.fromDate(deadline!)
                                  : null,
                              'completed': false,
                              'createdAt': Timestamp.now(),
                              'updatedAt': Timestamp.now(),
                            });

                            if (Navigator.canPop(bottomSheetContext)) {
                              Navigator.of(bottomSheetContext).pop();
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Goal added successfully!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                ),
                              );
                            }
                          }
                        },
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
                            borderRadius:
                            BorderRadius.circular(12.r),
                          ),
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

  // ─────────────────────────────────────────────
  // AUTO-SAVE: Check if any budget period ended
  // ─────────────────────────────────────────────
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
        .get();

    for (var doc in budgetsSnapshot.docs) {
      final budget = doc.data();
      final endDate = (budget['endDate'] as Timestamp?)?.toDate();

      if (endDate != null && endDate.isBefore(now)) {
        final remaining = (budget['amount'] ?? 0).toDouble() -
            (budget['used'] ?? 0).toDouble();

        if (remaining > 0 && budget['savingsGoalId'] != null) {
          await _autoSaveToGoal(
            budgetId: doc.id,
            goalId: budget['savingsGoalId'],
            amount: remaining,
            budgetName: budget['name'] ?? 'Budget',
          );
        }
      }
    }
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
      'closedAt': Timestamp.now(),
      'savedAmount': amount,
    });

    await batch.commit();

    final targetAmount = (goalDoc.data()?['targetAmount'] ?? 0).toDouble();
    if (newAmount >= targetAmount) {
      await _triggerGoalCompletion(
        goalId: goalId,
        goalName: goalDoc.data()?['name'] ?? 'Goal',
        targetAmount: targetAmount,
      );
    } else {
      await NotificationService.showNotification(
        title: 'Monthly Savings Saved!',
        body: '\$${amount.toStringAsFixed(0)} from "$budgetName" saved to "${goalDoc.data()?['name']}"!',
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

    await NotificationService.showNotification(
      title: 'Goal Achieved!',
      body: 'You\'ve reached \$${targetAmount.toStringAsFixed(0)} for "$goalName"!',
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

  // ─────────────────────────────────────────────
  // AI: Now based on INCOME vs EXPENSES
  // ─────────────────────────────────────────────
  Future<void> _generateAiData() async {
    setState(() => _loadingAi = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingAi = false);
      return;
    }

    try {
      final budgetsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('budgets')
          .where('active', isEqualTo: true)
          .get();

      double totalIncome = 0;
      for (var doc in budgetsSnapshot.docs) {
        totalIncome += (doc.data()['amount'] ?? 0).toDouble();
      }

      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .where('type', isEqualTo: 'expense')
          .get();

      double totalExpense = 0;
      Map<String, double> expenseCategories = {};

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        totalExpense += amount;

        final category = data['category'] ?? 'other';
        if (category is String) {
          expenseCategories[category] = (expenseCategories[category] ?? 0) + amount;
        } else if (category is List) {
          for (var c in category) {
            expenseCategories[c] = (expenseCategories[c] ?? 0) + amount;
          }
        }
      }

      double totalUsed = 0;
      for (var doc in budgetsSnapshot.docs) {
        totalUsed += (doc.data()['used'] ?? 0).toDouble();
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
          "budgets": budgetsSnapshot.docs.map((d) => {
            'id': d.id,
            ...d.data(),
          }).toList(),
        };
        _loadingAi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAi = false);
      debugPrint('Error generating AI data: $e');
    }
  }

  void _showAskAIDialog() {
    if (_aiResult == null) {
      _generateAiData().then((_) {
        if (_aiResult != null && mounted) _showPlanTypeDialog();
      });
      return;
    }
    _showPlanTypeDialog();
  }

  void _showPlanTypeDialog() {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Choose Your AI Plan',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Total Income: \$${_aiResult!['totalIncome'].toStringAsFixed(0)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
            ),
            Text(
              'Available: \$${_aiResult!['remaining'].toStringAsFixed(0)}',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 24.h),
            _buildPlanOption(
              icon: Icons.calendar_month,
              title: 'Monthly Saving Plan',
              subtitle: 'Based on your income & expenses',
              color: Colors.deepPurple,
              onTap: () => _generateAndShowPlan('monthly'),
            ),
            SizedBox(height: 12.h),
            _buildPlanOption(
              icon: Icons.calendar_today,
              title: 'Yearly Wealth Plan',
              subtitle: 'Long-term strategy with goals',
              color: Colors.teal,
              onTap: () => _generateAndShowPlan('yearly'),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
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
      if (mounted) Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 300));
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
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      if (plan.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI returned empty plan')),
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
    } catch (e, stack) {
      debugPrint('AI ERROR: $e');
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();
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

  // ✅ FIXED: Dynamic FAB based on current tab - ALWAYS shows Add Goal in Goals tab
  Widget? _buildFloatingActionButton() {
    // Income tab (index 0) - show Ask AI + Add Income
    if (_tabController.index == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: "ai_btn",
            onPressed: _loadingAi ? null : _showAskAIDialog,
            backgroundColor: Colors.orange.shade600,
            icon: _loadingAi
                ? SizedBox(
              width: 20.w,
              height: 20.h,
              child: CircularProgressIndicator(
                strokeWidth: 2.w,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text(
              'Ask AI',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          SizedBox(height: 25.h),

          FloatingActionButton.extended(
            heroTag: "add_income_btn",
            onPressed: () => _showAddIncomeDialog(context),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              'Add Income',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // Goals tab (index 1) - ALWAYS show Add Goal FAB (not conditional on goals existing)
    if (_tabController.index == 1) {
      return FloatingActionButton.extended(
        heroTag: "add_goal_btn",
        onPressed: () => _showAddGoalDialog(context),
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Goal',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Center(
          child: Text(
            'Budget & Goals',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 25.sp,
              color: Colors.white,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Income', icon: Icon(Icons.account_balance_wallet)),
            Tab(text: 'Goals', icon: Icon(Icons.flag)),
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
      floatingActionButton: _buildFloatingActionButton(),
    );
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
                  'Tap "Add Income" to add your salary!',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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

            return Card(
              margin: EdgeInsets.only(bottom: 12.h),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
                side: autoSave
                    ? BorderSide(color: Colors.green, width: 2)
                    : BorderSide.none,
              ),
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
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            _getIncomeIcon(category),
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                budgetName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.sp,
                                ),
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
                                horizontal: 8.w, vertical: 4.h),
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
                            if (value == 'delete') _deleteBudget(docId);
                            if (value == 'add_expense') _showAddExpenseDialog(docId, budgetName);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'add_expense',
                              child: Row(
                                children: [
                                  Icon(Icons.remove_circle, color: Colors.orange),
                                  SizedBox(width: 8.w),
                                  Text('Add Expense'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8.w),
                                  Text('Delete'),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${used.toStringAsFixed(0)} used',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          isOver
                              ? 'Over by \$${(-remaining).toStringAsFixed(0)}!'
                              : '\$${remaining.toStringAsFixed(0)} left',
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
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.savings, size: 16.sp, color: Colors.green),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                '\$${remaining.toStringAsFixed(0)} will auto-save when period ends',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
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
            );
          },
        );
      },
    );
  }

  void _showAddExpenseDialog(String budgetId, String budgetName) {
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
                          final currentUsed = (budgetDoc.data()?['used'] ?? 0).toDouble();

                          batch.update(budgetRef, {
                            'used': currentUsed + amount,
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
      builder: (context) => AlertDialog(
        title: const Text('Update Goal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Goal Name',
                  prefixIcon: Icon(Icons.flag),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: currentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Current Amount Saved',
                  prefixText: '\$ ',
                  prefixIcon: Icon(Icons.savings),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Amount',
                  prefixText: '\$ ',
                  prefixIcon: Icon(Icons.attach_money),
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddIncomeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final sourceController = TextEditingController();

    String selectedCategory = 'salary';
    String selectedPeriod = 'monthly';
    DateTime? endDate;
    String? linkedGoalId;

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
                        hintText: 'e.g., Monthly Salary',
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
                        labelText: 'Source',
                        hintText: 'e.g., Company XYZ, Client ABC',
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
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
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
                            ? 'Period End Date (for auto-save)'
                            : DateFormat('MMM dd, yyyy').format(endDate!),
                        style: TextStyle(
                          color: endDate == null ? Colors.grey : Colors.black,
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                    ),
                    SizedBox(height: 16.h),
                    if (_goalsList.isNotEmpty) ...[
                      Text(
                        'Auto-save remainder to Goal',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      DropdownButtonFormField<String>(
                        value: linkedGoalId,
                        hint: const Text('Select Goal (Optional)'),
                        items: _goalsList.map((goal) {
                          return DropdownMenuItem(
                            value: goal['id'] as String,
                            child: Text(goal['name'] ?? 'Unnamed'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() => linkedGoalId = value);
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final amount = double.tryParse(amountController.text) ?? 0;

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter income name')),
                            );
                            return;
                          }

                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter valid amount')),
                            );
                            return;
                          }

                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return;

                          final calculatedEndDate = endDate ??
                              (selectedPeriod == 'monthly'
                                  ? DateTime.now().add(const Duration(days: 30))
                                  : selectedPeriod == 'weekly'
                                  ? DateTime.now().add(const Duration(days: 7))
                                  : DateTime.now().add(const Duration(days: 30)));

                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('budgets')
                                .add({
                              'name': name,
                              'amount': amount,
                              'source': sourceController.text.trim(),
                              'category': selectedCategory,
                              'period': selectedPeriod,
                              'startDate': Timestamp.now(),
                              'endDate': Timestamp.fromDate(calculatedEndDate),
                              'used': 0,
                              'remaining': amount,
                              'autoSave': linkedGoalId != null,
                              'savingsGoalId': linkedGoalId,
                              'active': true,
                              'createdAt': Timestamp.now(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Income added! Track expenses against it.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
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
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
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
                // Center button for first goal (optional, FAB also available)
                ElevatedButton.icon(
                  onPressed: () => _showAddGoalDialog(context),
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
                    ? BorderSide(color: Colors.green, width: 2)
                    : BorderSide.none,
              ),
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
                                  'Target: ${DateFormat('MMM dd, yyyy').format(deadline.toDate())}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
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
                          onSelected: (value) {
                            if (value == 'delete') _deleteGoal(docId);
                            if (value == 'edit')
                              _showEditGoalDialog(context, docId, goal);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.blue),
                                  SizedBox(width: 8.w),
                                  Text('Edit'),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${currentAmount.toStringAsFixed(0)} saved',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          '\$${targetAmount.toStringAsFixed(0)} target',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteBudget(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('budgets')
          .doc(docId)
          .update({'active': false});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Income source removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteGoal(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  IconData _getIncomeIcon(String c) {
    switch (c) {
      case 'salary':
        return Icons.work;
      case 'freelance':
        return Icons.laptop;
      case 'investment':
        return Icons.trending_up;
      case 'business':
        return Icons.store;
      case 'gift':
        return Icons.card_giftcard;
      case 'bonus':
        return Icons.star;
      default:
        return Icons.account_balance_wallet;
    }
  }
}