import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  final String apiKey;

  GroqService({required this.apiKey});

  Future<String> getExpenseInsight(
      List<Map<String, dynamic>> transactions, {
        String language = 'en',
      }) async {
    if (transactions.isEmpty) {
      return language == 'ar'
          ? 'لا توجد معاملات لتحليلها.'
          : 'No transactions to analyze.';
    }

    // تجميع البيانات
    final Map<String, double> categoryTotals = {};
    double totalIncome = 0;
    double totalExpense = 0;

    for (var t in transactions) {
      final amount = (t['amount'] ?? 0).toDouble();
      final type = t['type'] ?? 'expense';
      final category = t['category']?.toString() ?? 'other';

      if (type == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      }
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sortedCategories.take(5).map((e) =>
    "${e.key}: \$${e.value.toStringAsFixed(2)}"
    ).join("\n");

    // ✅ بناء الـ Prompt حسب اللغة
    final isArabic = language == 'ar';

    final systemPrompt = isArabic
        ? "You are a helpful financial advisor. Always respond in Arabic (Fusha) with short, practical advice."
        : "You are a helpful financial advisor. Always respond in English with short, practical advice.";

    final userPrompt = isArabic
        ? """
You are a financial expert. Analyze this data and give ONE short, practical financial advice in Arabic (1-2 sentences only):

Total Income: \$${totalIncome.toStringAsFixed(2)}
Total Expenses: \$${totalExpense.toStringAsFixed(2)}
Net: \$${(totalIncome - totalExpense).toStringAsFixed(2)}

Top Expense Categories:
$topCategories

Requirements:
- Short (under 150 characters)
- Practical and actionable
- In Arabic (Fusha)
- No introductions, just the advice
"""
        : """
You are a financial expert. Analyze this data and give ONE short, practical financial advice in English (1-2 sentences only):

Total Income: \$${totalIncome.toStringAsFixed(2)}
Total Expenses: \$${totalExpense.toStringAsFixed(2)}
Net: \$${(totalIncome - totalExpense).toStringAsFixed(2)}

Top Expense Categories:
$topCategories

Requirements:
- Short (under 150 characters)
- Practical and actionable
- In English
- No introductions, just the advice
""";

    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system",
              "content": systemPrompt,
            },
            {
              "role": "user",
              "content": userPrompt,
            }
          ],
          "temperature": 0.7,
          "max_tokens": 150,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data["choices"]?[0]?["message"]?["content"];
        return text?.toString().trim() ?? (isArabic ? "لم يتم الحصول على نصيحة." : "No advice received.");
      } else {
        print("Status Code: ${response.statusCode}");
        print("Response Body: ${response.body}");
        return isArabic
            ? "خطأ ${response.statusCode}"
            : "Error ${response.statusCode}";
      }
    } catch (e) {
      return isArabic
          ? "حدث خطأ: ${e.toString()}"
          : "An error occurred: ${e.toString()}";
    }
  }
}
