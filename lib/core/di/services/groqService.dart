import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqService {
  final String apiKey;

  GroqService({required this.apiKey});

  Future<String> getExpenseInsight(List<Map<String, dynamic>> transactions) async {
    if (transactions.isEmpty) return 'لا توجد معاملات لتحليلها.';

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

    final prompt = """
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
""";

    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile", // ← النموذج الجديد
          "messages": [
            {
              "role": "system",
              "content": "You are a helpful financial advisor. Always respond in Arabic (Fusha) with short, practical advice."
            },
            {
              "role": "user",
              "content": prompt
            }
          ],
          "temperature": 0.7,
          "max_tokens": 150,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data["choices"]?[0]?["message"]?["content"];
        return text?.toString().trim() ?? "لم يتم الحصول على نصيحة.";
      } else {
        print("Status Code: ${response.statusCode}");
        print("Response Body: ${response.body}");
        return "خطأ ${response.statusCode}";
      }
    } catch (e) {
      return "حدث خطأ: ${e.toString()}";
    }
  }
}