import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../notifications/notification_service.dart';

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
    required String languageCode, // 'ar' or 'en'
    required String currencySymbol,
  }) async {
    if (_openRouterKey.isEmpty) {
      throw Exception(
        'OpenRouter API Key is missing. Add OPENROUTER_API_KEY to .env file',
      );
    }

    final goalsContext = _buildGoalsContext(goals, currencySymbol);
    final budgetsContext = _buildBudgetsContext(budgets, currencySymbol);
    final categoriesText = categories.entries
        .map((e) => '${e.key}: $currencySymbol${e.value.toStringAsFixed(2)}')
        .join('\n');
    final isArabic = languageCode == 'ar';

    final languageInstruction = isArabic
        ? '⚠️ مهم جدًا جدًا: يجب أن يكون الرد بالكامل باللغة العربية الفصحى فقط. لا تستخدم أي كلمة إنجليزية إطلاقًا، حتى في العناوين. حافظ على الأرقام والرموز (\$, %) كما هي.'
        : '⚠️ VERY IMPORTANT: The entire response must be written in English only.';

    final systemLanguageInstruction = isArabic
        ? 'You must respond ONLY in Modern Standard Arabic (العربية الفصحى). Do not use any English words. Keep numbers, currency symbols and percentages as-is.'
        : 'You must respond ONLY in English.';

    final planPrompt = """
$languageInstruction

💰 SMART FINANCIAL ANALYSIS: BUDGET • SAVINGS • GOALS

📊 Financial Overview:
━━━━━━━━━━━━━━━━━━━━━
💵 Total Budget: $currencySymbol${income.toStringAsFixed(2)}
📉 Total Expenses: $currencySymbol${expense.toStringAsFixed(2)}
💰 Available Budget: $currencySymbol${savings.toStringAsFixed(2)}
📈 Savings Potential: ${income > 0 ? ((savings / income) * 100).toStringAsFixed(1) : 0}%

💵 Active Budgets:
$budgetsContext

📂 Expense Breakdown:
$categoriesText

$goalsContext

🎯 INSTRUCTIONS:
Create a comprehensive ${planType.toUpperCase()} financial plan that CONNECTS Available Budget, Savings & Goals.

Requirements:
1. **BUDGET ANALYSIS**: Analyze each active budget's remaining amount and recommend optimal allocation
2. **GOALS-BUDGET LINK**: For EACH goal, show:
   - Exact amount to save from Available Budget
   - Which specific budget(s) to allocate from
   - Recommended auto-save percentage per budget
   - Timeline: "At this rate, you'll reach [Goal] by [Date]"
3. **SAVINGS STRATEGY**:
   - Apply 50/30/20 rule to Available Budget
Emergency fund priority (3-6 months expenses = $currencySymbol${(expense * 3).toStringAsFixed(0)} - $currencySymbol${(expense * 6).toStringAsFixed(0)})
   - Balance multiple goals with available resources
4. **FEASIBILITY CHECK**:
   - If goals exceed Available Budget, rank by urgency & suggest adjustments
   - Show "Goal Gap" and how to close it (reduce expenses, extend deadline, or increase budget)
5. **ACTIONABLE STEPS**:
   - Week-by-week spending limits per category
   - Monthly savings targets per goal
   - Auto-save setup recommendations
6. Use emojis, clear sections, bullet points, and specific dollar amounts
7. Be encouraging but realistic about timeline

Example format:
"🚗 Buy a Car ($currencySymbol 250,000)
   Current: $currencySymbol 5,000 (2%) | Remaining: $currencySymbol 245,000
   📅 Deadline: Dec 2027 (18 months left)
   ⭐ NEED: $currencySymbol 13,611/month from Available Budget
   💡 SOURCE: Allocate 40% of Salary Budget ($currencySymbol 20,000/mo)
   ✅ PROJECTED: Reach goal by Nov 2027 (1 month early!)
   🔄 AUTO-SAVE: Set 40% auto-save from 'Monthly Salary' budget"

$languageInstruction
""";

    final response = await http.post(
      Uri.parse(_openRouterUrl),
      headers: {
        'Authorization': 'Bearer $_openRouterKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://virello.app',
        'X-Title': 'Peko Budget AI',
      },
      body: jsonEncode({
        "model": "google/gemini-2.5-flash",
        "messages": [
          {
            "role": "system",
            "content":
            "You are an expert financial advisor working inside 'Peko: AI Expense Tracker' app, specializing in income-based savings planning and goal achievement. Provide detailed, actionable advice with exact calculations. Focus on allocating income sources to goals, not limiting spending. $systemLanguageInstruction"
          },
          {
            "role": "user",
            "content": planPrompt
          }
        ],
        "temperature": 0.7,
        "max_tokens": 1800,
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
  static String _buildGoalsContext(List<Map<String, dynamic>>? goals, String currencySymbol) {
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
            '✅ $name - COMPLETED! ($currencySymbol${current.toStringAsFixed(0)} / $currencySymbol${target.toStringAsFixed(0)})');
        continue;
      }

      final remaining = target - current;
      final progress = target > 0 ? (current / target * 100) : 0;

      buffer.write('🚩 $name\n');
      buffer.write(
          '   Current: $currencySymbol${current.toStringAsFixed(0)} / $currencySymbol${target.toStringAsFixed(0)} (${progress.toStringAsFixed(1)}%)\n');
      buffer.write('   Remaining: $currencySymbol${remaining.toStringAsFixed(0)}\n');

      if (deadline != null) {
        final targetDate = deadline.toDate();
        final now = DateTime.now();
        final monthsLeft = _calculateMonthsLeft(now, targetDate);
        final daysLeft = targetDate.difference(now).inDays;

        buffer.write('   Deadline: ${DateFormat('MMM dd, yyyy').format(targetDate)}\n');
        buffer.write('   Time Left: $monthsLeft months ($daysLeft days)\n');

        if (monthsLeft > 0) {
          final monthlyNeeded = remaining / monthsLeft;
          buffer.write('   ⭐ REQUIRED: $currencySymbol${monthlyNeeded.toStringAsFixed(0)}/month to reach this goal\n');
        } else if (daysLeft > 0) {
          final dailyNeeded = remaining / daysLeft;
          buffer.write('   ⚠️ URGENT: $currencySymbol${dailyNeeded.toStringAsFixed(0)}/day needed!\n');
        } else {
          buffer.write('   ❌ DEADLINE PASSED - Goal overdue!\n');
        }
      }

      if (monthlySavings > 0) {
        buffer.write('   💰 Auto-saving: $currencySymbol${monthlySavings.toStringAsFixed(0)}/month\n');
      }

      buffer.writeln('');
    }

    return buffer.toString();
  }



  // ─────────────────────────────────────────────
  // BUILD BUDGETS/INCOME CONTEXT FOR AI
  // ─────────────────────────────────────────────
  static String _buildBudgetsContext(List<Map<String, dynamic>>? budgets, String currencySymbol) {
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
          '- 💵 $name: $currencySymbol${amount.toStringAsFixed(0)} [$category/$period]\n');
      if (source.isNotEmpty) {
        buffer.write('  Source: $source\n');
      }
      buffer.write(
          '  Used: $currencySymbol${used.toStringAsFixed(0)} | Left: $currencySymbol${remaining.toStringAsFixed(0)}\n');
      if (autoSave) {
        final goalName = b['savingsGoalName'] ?? 'Goal';
        buffer.write(
            '  🔄 Auto-save: $currencySymbol${remaining.toStringAsFixed(0)} to "$goalName" when period ends\n');
      }
      buffer.write('\n');
    }

    buffer.write(
        '━━━━━━━━━━━━━━━━━━━━━\nTotal Income: $currencySymbol${totalIncome.toStringAsFixed(0)} | Total Used: $currencySymbol${totalUsed.toStringAsFixed(0)} | Available: $currencySymbol${(totalIncome - totalUsed).toStringAsFixed(0)}\n');

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

      // ✅ Save to Firestore + Show system notification
      await _saveAndNotify(
        userId: user.uid,
        title: '💰 Savings Added!',
        body: '\$${amount.toStringAsFixed(0)} saved to "${goalData['name']}"! Progress: $progress%',
        type: 'savings_progress',
        data: {
          'goalId': goalId,
          'amount': amount,
          'screen': '/budget',
          'tab': 'goals',
        },
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

    // ✅ Save to Firestore + Show system notification
    await _saveAndNotify(
      userId: userId,
      title: '🎉 Goal Achieved! 🏆',
      body: 'Amazing! You\'ve saved \$${targetAmount.toStringAsFixed(0)} for "${goalData['name']}"! Time to celebrate! 🎊',
      type: 'goal_completion',
      data: {
        'goalId': goalId,
        'screen': '/budget',
        'tab': 'goals',
      },
    );
  }

  // ─────────────────────────────────────────────
  // ✅ NEW: Unified Save & Notify Helper
  // ─────────────────────────────────────────────
  static Future<void> _saveAndNotify({
    required String userId,
    required String title,
    required String body,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    // 1. Save to Firestore (for Notification Screen)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'screen': data['screen'],
      'tab': data['tab'],
      'data': data,
      'createdAt': Timestamp.now(),
    });

    // 2. Show system notification (payload for deep linking)
    await NotificationService.showNotification(
      title: title,
      body: body,
      type: type,
      data: data,
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