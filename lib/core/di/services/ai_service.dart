import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class AIService {
  static String get _openRouterKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';

  static const String _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  // ─────────────────────────────────────────────
  // GENERATE AI PLAN (Income-Based)
  // ─────────────────────────────────────────────
  static Future<String> generatePlan({
    required double income,
    required double expense,
    required Map<String, double> categories,
    required String planType,
    required double savings,
    List<Map<String, dynamic>>? goals,
    List<Map<String, dynamic>>? budgets,
  }) async {
    if (_openRouterKey.isEmpty) {
      throw Exception(
        'OpenRouter API Key is missing. Add OPENROUTER_API_KEY to .env file',
      );
    }

    final goalsContext = _buildGoalsContext(goals);
    final budgetsContext = _buildBudgetsContext(budgets);
    final categoriesText = categories.entries
        .map((e) => '${e.key}: \$${e.value.toStringAsFixed(2)}')
        .join('\n');

    final planPrompt = """
💰 INCOME-BASED FINANCIAL ANALYSIS & SAVINGS PLAN

📊 Financial Summary:
━━━━━━━━━━━━━━━━━━━━━
💵 Total Income: \$${income.toStringAsFixed(2)}
📉 Total Expenses: \$${expense.toStringAsFixed(2)}
📈 Available to Save: \$${savings.toStringAsFixed(2)}
💰 Savings Rate: ${income > 0 ? ((savings / income) * 100).toStringAsFixed(1) : 0}%

💵 Income Sources:
$budgetsContext

📂 Expense Breakdown:
$categoriesText

$goalsContext

🎯 INSTRUCTIONS:
Create a detailed ${planType.toUpperCase()} financial plan based on INCOME ALLOCATION (not spending limits).

Requirements:
1. Analyze income sources stability and reliability
2. Calculate optimal savings rate from available income
3. For EACH goal: Show exact monthly contribution needed and which income source to allocate from
4. Show timeline projection: "At this rate, you'll reach [Goal] by [Date]"
5. If savings are insufficient for goals, suggest:
   - Which expenses to reduce
   - Additional income needed
   - Extended timeline
6. Include emergency fund recommendation (3-6 months of expenses)
7. Provide weekly action steps
8. Use emojis, clear sections, and bullet points
9. Be specific with numbers and percentages

Example format:
"🚗 Buy a Car (\$250,000)
   Current: \$5,000 (2%)
   Need: \$2,083/month for 120 months
   Source: Allocate 15% of Monthly Salary
   Projected: Reach goal by October 2027"
""";

    final response = await http.post(
      Uri.parse(_openRouterUrl),
      headers: {
        'Authorization': 'Bearer $_openRouterKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://virello.app',
        'X-Title': 'Virello Budget AI',
      },
      body: jsonEncode({
        "model": "google/gemini-2.5-flash",
        "messages": [
          {
            "role": "system",
            "content":
            "You are an expert financial advisor specializing in income-based savings planning and goal achievement. Provide detailed, actionable advice with exact calculations. Focus on allocating income sources to goals, not limiting spending."
          },
          {
            "role": "user",
            "content": planPrompt
          }
        ],
        "temperature": 0.7,
        "max_tokens": 2048,
      }),
    );

    debugPrint('========== OPENROUTER ==========');
    debugPrint('STATUS: ${response.statusCode}');
    debugPrint('BODY: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('AI Error: ${response.statusCode}\n${response.body}');
    }

    final data = jsonDecode(response.body);

    if (data['choices'] != null &&
        data['choices'].isNotEmpty &&
        data['choices'][0]['message'] != null) {
      return data['choices'][0]['message']['content'] ?? '';
    }

    throw Exception('Invalid AI response format\n${response.body}');
  }

  // ─────────────────────────────────────────────
  // BUILD GOALS CONTEXT FOR AI
  // ─────────────────────────────────────────────
  static String _buildGoalsContext(List<Map<String, dynamic>>? goals) {
    if (goals == null || goals.isEmpty) {
      return '\n🎯 Active Goals: None set yet. Consider adding a goal first!\n';
    }

    final buffer = StringBuffer('\n🎯 Active Goals:\n━━━━━━━━━━━━━━━━━━━━━\n');

    for (var goal in goals) {
      final name = goal['name'] ?? 'Unnamed Goal';
      final target = (goal['targetAmount'] ?? 0).toDouble();
      final current = (goal['currentAmount'] ?? 0).toDouble();
      final deadline = goal['deadline'] as Timestamp?;
      final completed = goal['completed'] ?? false;
      final monthlySavings = goal['monthlySavingsAmount'] ?? 0.0;

      if (completed) {
        buffer.writeln(
            '✅ $name - COMPLETED! (\$${current.toStringAsFixed(0)} / \$${target.toStringAsFixed(0)})');
        continue;
      }

      final remaining = target - current;
      final progress = target > 0 ? (current / target * 100) : 0;

      buffer.write('🚩 $name\n');
      buffer.write(
          '   Current: \$${current.toStringAsFixed(0)} / \$${target.toStringAsFixed(0)} (${progress.toStringAsFixed(1)}%)\n');
      buffer.write('   Remaining: \$${remaining.toStringAsFixed(0)}\n');

      if (deadline != null) {
        final targetDate = deadline.toDate();
        final now = DateTime.now();
        final monthsLeft = _calculateMonthsLeft(now, targetDate);
        final daysLeft = targetDate.difference(now).inDays;

        buffer.write(
            '   Deadline: ${DateFormat('MMM dd, yyyy').format(targetDate)}\n');
        buffer.write('   Time Left: $monthsLeft months ($daysLeft days)\n');

        if (monthsLeft > 0) {
          final monthlyNeeded = remaining / monthsLeft;
          buffer.write(
              '   ⭐ REQUIRED: \$${monthlyNeeded.toStringAsFixed(0)}/month to reach this goal\n');
        } else if (daysLeft > 0) {
          final dailyNeeded = remaining / daysLeft;
          buffer.write(
              '   ⚠️ URGENT: \$${dailyNeeded.toStringAsFixed(0)}/day needed!\n');
        } else {
          buffer.write('   ❌ DEADLINE PASSED - Goal overdue!\n');
        }
      }

      if (monthlySavings > 0) {
        buffer.write(
            '   💰 Auto-saving: \$${monthlySavings.toStringAsFixed(0)}/month\n');
      }

      buffer.writeln('');
    }

    return buffer.toString();
  }

  // ─────────────────────────────────────────────
  // BUILD BUDGETS/INCOME CONTEXT FOR AI
  // ─────────────────────────────────────────────
  static String _buildBudgetsContext(List<Map<String, dynamic>>? budgets) {
    if (budgets == null || budgets.isEmpty) {
      return 'No active income sources. Add your salary or other income first!\n';
    }

    final buffer = StringBuffer();
    double totalIncome = 0;
    double totalUsed = 0;

    for (var b in budgets) {
      final name = b['name'] ?? 'Unnamed';
      final amount = (b['amount'] ?? 0).toDouble();
      final used = (b['used'] ?? 0).toDouble();
      final remaining = amount - used;
      final category = b['category'] ?? 'other';
      final period = b['period'] ?? 'monthly';
      final autoSave = b['autoSave'] ?? false;
      final source = b['source'] ?? '';

      totalIncome += amount;
      totalUsed += used;

      buffer.write(
          '- 💵 $name: \$${amount.toStringAsFixed(0)} [$category/$period]\n');
      if (source.isNotEmpty) {
        buffer.write('  Source: $source\n');
      }
      buffer.write(
          '  Used: \$${used.toStringAsFixed(0)} | Left: \$${remaining.toStringAsFixed(0)}\n');
      if (autoSave) {
        final goalName = b['savingsGoalName'] ?? 'Goal';
        buffer.write(
            '  🔄 Auto-save: \$${remaining.toStringAsFixed(0)} to "$goalName" when period ends\n');
      }
      buffer.write('\n');
    }

    buffer.write(
        '━━━━━━━━━━━━━━━━━━━━━\nTotal Income: \$${totalIncome.toStringAsFixed(0)} | Total Used: \$${totalUsed.toStringAsFixed(0)} | Available: \$${(totalIncome - totalUsed).toStringAsFixed(0)}\n');

    return buffer.toString();
  }

  static int _calculateMonthsLeft(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + (to.month - from.month);
  }

  // ─────────────────────────────────────────────
  // AUTO-SAVE MONTHLY SAVINGS TO GOAL
  // ─────────────────────────────────────────────
  static Future<void> saveMonthlySavingsToGoal({
    required String goalId,
    required double amount,
    required String planType,
    String? budgetId,
    String? budgetName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final goalDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(goalId)
        .get();

    if (!goalDoc.exists) throw Exception('Goal not found');

    final goalData = goalDoc.data()!;
    final currentAmount = (goalData['currentAmount'] ?? 0).toDouble();
    final targetAmount = (goalData['targetAmount'] ?? 0).toDouble();
    final newAmount = currentAmount + amount;

    final batch = FirebaseFirestore.instance.batch();

    // 1. Update goal
    final goalRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('goals')
        .doc(goalId);

    batch.update(goalRef, {
      'currentAmount': newAmount,
      'lastSavingsDate': Timestamp.now(),
      'monthlySavingsAmount': amount,
      'linkedPlanType': planType,
      'updatedAt': Timestamp.now(),
    });

    // 2. Log savings transaction
    final transRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .doc();

    batch.set(transRef, {
      'type': 'savings',
      'amount': amount,
      'category': ['savings', 'goal'],
      'goalId': goalId,
      'goalName': goalData['name'],
      'budgetId': budgetId,
      'budgetName': budgetName,
      'description':
      'Auto-savings: ${goalData['name']} from ${budgetName ?? planType} plan',
      'date': Timestamp.now(),
      'createdAt': Timestamp.now(),
    });

    // 3. Create savings record
    final savingsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('savings')
        .doc();

    batch.set(savingsRef, {
      'amount': amount,
      'goalId': goalId,
      'goalName': goalData['name'],
      'sourceBudgetId': budgetId,
      'sourceBudgetName': budgetName,
      'planType': planType,
      'period': DateFormat('yyyy-MM').format(DateTime.now()),
      'createdAt': Timestamp.now(),
    });

    await batch.commit();

    // Check goal completion
    if (newAmount >= targetAmount) {
      await _markGoalCompleted(
        userId: user.uid,
        goalId: goalId,
        goalData: goalData,
        targetAmount: targetAmount,
      );
    } else {
      // Progress notification
      final progress = (newAmount / targetAmount * 100).toStringAsFixed(1);
      await NotificationService.showNotification(
        title: '💰 Savings Added!',
        body:
        '\$${amount.toStringAsFixed(0)} saved to "${goalData['name']}"! Progress: $progress%',
        payload: jsonEncode({
          'type': 'savings_progress',
          'goalId': goalId,
          'amount': amount,
        }),
      );
    }
  }

  // ─────────────────────────────────────────────
  // MARK GOAL AS COMPLETED + NOTIFY
  // ─────────────────────────────────────────────
  static Future<void> _markGoalCompleted({
    required String userId,
    required String goalId,
    required Map<String, dynamic> goalData,
    required double targetAmount,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc(goalId)
        .update({
      'completed': true,
      'completedAt': Timestamp.now(),
    });

    // Save notification to Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'title': '🎉 Goal Achieved!',
      'body':
      'Congratulations! You\'ve reached your goal "${goalData['name']}" with \$${targetAmount.toStringAsFixed(0)}!',
      'type': 'goal_completion',
      'goalId': goalId,
      'read': false,
      'createdAt': Timestamp.now(),
    });

    // Trigger local notification
    await NotificationService.showNotification(
      title: '🎉 Goal Achieved! 🏆',
      body:
      'Amazing! You\'ve saved \$${targetAmount.toStringAsFixed(0)} for "${goalData['name']}"! Time to celebrate! 🎊',
      payload: jsonEncode({
        'type': 'goal_completion',
        'goalId': goalId,
      }),
    );
  }

  // ─────────────────────────────────────────────
  // CALCULATE REQUIRED MONTHLY SAVINGS PER GOAL
  // ─────────────────────────────────────────────
  static Map<String, double> calculateRequiredSavings({
    required List<Map<String, dynamic>> goals,
    required double availableSavings,
  }) {
    final Map<String, double> allocations = {};
    double totalRequired = 0;

    for (var goal in goals) {
      if (goal['completed'] == true) continue;

      final target = (goal['targetAmount'] ?? 0).toDouble();
      final current = (goal['currentAmount'] ?? 0).toDouble();
      final deadline = goal['deadline'] as Timestamp?;
      final remaining = target - current;

      if (deadline == null || remaining <= 0) continue;

      final targetDate = deadline.toDate();
      final monthsLeft = _calculateMonthsLeft(DateTime.now(), targetDate);

      if (monthsLeft > 0) {
        final monthlyNeeded = remaining / monthsLeft;
        allocations[goal['id'] ?? goal['name']] = monthlyNeeded;
        totalRequired += monthlyNeeded;
      }
    }

    // If total required exceeds available, scale proportionally
    if (totalRequired > availableSavings && totalRequired > 0) {
      final scale = availableSavings / totalRequired;
      allocations.updateAll((key, value) => value * scale);
    }

    return allocations;
  }

  // ─────────────────────────────────────────────
  // PROCESS EXPIRED BUDGETS (AUTO-SAVE REMAINDER)
  // ─────────────────────────────────────────────
  static Future<void> processExpiredBudgets() async {
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
        final totalAmount = (budget['amount'] ?? 0).toDouble();
        final used = (budget['used'] ?? 0).toDouble();
        final remaining = totalAmount - used;

        if (remaining > 0 && budget['savingsGoalId'] != null) {
          // Save remainder to goal
          await saveMonthlySavingsToGoal(
            goalId: budget['savingsGoalId'],
            amount: remaining,
            planType: budget['period'] ?? 'monthly',
            budgetId: doc.id,
            budgetName: budget['name'],
          );

          // Close budget
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('budgets')
              .doc(doc.id)
              .update({
            'active': false,
            'closedAt': Timestamp.now(),
            'savedAmount': remaining,
            'status': 'auto_saved',
          });
        }
      }
    }
  }

  // ─────────────────────────────────────────────
  // GET AI SAVINGS RECOMMENDATION
  // ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSavingsRecommendation({
    required double income,
    required double expenses,
    required List<Map<String, dynamic>> goals,
  }) async {
    final savings = income - expenses;
    final recommendations = <String, dynamic>{};

    // 50/30/20 rule recommendation
    final needs = income * 0.5;
    final wants = income * 0.3;
    final savingsTarget = income * 0.2;

    recommendations['rule_50_30_20'] = {
      'needs': needs,
      'wants': wants,
      'savings': savingsTarget,
      'current_savings': savings,
      'on_track': savings >= savingsTarget,
    };

    // Goal feasibility
    for (var goal in goals) {
      if (goal['completed'] == true) continue;

      final target = (goal['targetAmount'] ?? 0).toDouble();
      final current = (goal['currentAmount'] ?? 0).toDouble();
      final remaining = target - current;
      final deadline = goal['deadline'] as Timestamp?;

      if (deadline != null) {
        final monthsLeft = _calculateMonthsLeft(DateTime.now(), deadline.toDate());
        if (monthsLeft > 0) {
          final monthlyNeeded = remaining / monthsLeft;
          recommendations['goal_${goal['id']}'] = {
            'name': goal['name'],
            'feasible': monthlyNeeded <= savings,
            'monthly_needed': monthlyNeeded,
            'shortfall': monthlyNeeded > savings ? monthlyNeeded - savings : 0,
            'timeline_months': monthsLeft,
          };
        }
      }
    }

    return recommendations;
  }
}