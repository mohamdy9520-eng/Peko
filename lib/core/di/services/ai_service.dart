import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  static String get _openRouterKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';

  static const String _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static Future<String> generatePlan({
    required double income,
    required double expense,
    required Map<String, double> categories,
    required String planType,
    required double savings,
  }) async {
    if (_openRouterKey.isEmpty) {
      throw Exception(
        'OpenRouter API Key is missing. Add OPENROUTER_API_KEY to .env file',
      );
    }

    final categoriesText = categories.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');

    final planPrompt = """
Financial Summary

Income: $income
Expenses: $expense
Savings: $savings

Expense Categories:
$categoriesText

Create a detailed $planType financial plan.

Requirements:
- Analyze spending habits
- Suggest savings targets
- Give actionable recommendations
- Include budgeting strategy
- Use clear sections and bullet points
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
            "You are a professional financial advisor. Give practical and detailed financial advice."
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
      throw Exception(
        'AI Error: ${response.statusCode}\n${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data['choices'] != null &&
        data['choices'].isNotEmpty &&
        data['choices'][0]['message'] != null) {
      return data['choices'][0]['message']['content'] ?? '';
    }

    throw Exception(
      'Invalid AI response format\n${response.body}',
    );
  }
}