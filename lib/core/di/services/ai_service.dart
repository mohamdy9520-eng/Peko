import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static Future<String> generatePlan({
    required double income,
    required double expense,
    required Map<String, double> categories,
    required String planType, // monthly or yearly
    required double savings,
  }) async {
    final url = Uri.parse(
      "https://aiexpensetrackerfixed.vercel.app/api/finance",
    );

    final planPrompt = planType == 'monthly'
        ? """
Create a STRICT monthly saving plan based on:
- Monthly Income: \$${income.toStringAsFixed(2)}
- Monthly Expenses: \$${expense.toStringAsFixed(2)}
- Current Savings: \$${savings.toStringAsFixed(2)}
- Spending Categories: ${categories.entries.map((e) => "${e.key}: \$${e.value.toStringAsFixed(2)}").join(", ")}

Provide:
1. DAILY spending limit
2. WEEKLY checkpoints
3. MONTHLY saving target
4. 5 specific saving tips
5. Red flags/warnings if overspending

Format as a structured table.
"""
        : """
Create a YEARLY wealth building plan based on:
- Monthly Income: \$${income.toStringAsFixed(2)}
- Monthly Expenses: \$${expense.toStringAsFixed(2)}
- Current Savings: \$${savings.toStringAsFixed(2)}
- Spending Categories: ${categories.entries.map((e) => "${e.key}: \$${e.value.toStringAsFixed(2)}").join(", ")}

Provide:
1. MONTHLY saving targets for 12 months
2. QUARTERLY milestones
3. YEARLY goal projection
4. Investment suggestions
5. Progress tracking table

Format as a structured table.
""";

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer YOUR_API_KEY',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "income": income,
        "expense": expense,
        "categories": categories,
        "planType": planType,
        "savings": savings,
        "prompt": planPrompt,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'AI Error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    return data['choices'][0]['message']['content'];
  }
}