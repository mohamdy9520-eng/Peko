import 'dart:async';
import 'dart:convert';
import 'dart:io'; // مهم لـ SocketException
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../providers/currency_provider.dart';

class AIInsightService {
  final String apiKey;
  AIInsightService({required this.apiKey});

  Future<String> getExpenseInsight(
      List<Map<String, dynamic>> transactions, {
        required BuildContext context,
      }) async {
    final currencyProvider = context.read<CurrencyProvider>();
    final language = context.locale.languageCode;
    final isArabic = language == 'ar';

    final currencySymbol = currencyProvider.selectedCurrency.getLocalizedSymbol(language);
    final currencyCode = currencyProvider.code;
    final currencyName = currencyProvider.name;

    if (transactions.isEmpty) {
      return isArabic
          ? 'لا توجد معاملات لتحليلها.'
          : 'No transactions to analyze.';
    }

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

    final topCategories = sortedCategories.take(5).map((e) {
      final formattedAmount = _formatAmount(e.value, currencySymbol, isArabic);
      return "${e.key}: $formattedAmount";
    }).join("\n");

    final formattedIncome = _formatAmount(totalIncome, currencySymbol, isArabic);
    final formattedExpense = _formatAmount(totalExpense, currencySymbol, isArabic);
    final formattedNet = _formatAmount(totalIncome - totalExpense, currencySymbol, isArabic);

    final promptSymbol = isArabic ? currencySymbol : currencyCode;

    final systemPrompt = isArabic
        ? "أنت مستشار مالي خبير. رد دائماً بالعربية الفصحى بنصائح قصيرة وعملية. استخدم $currencyName ($promptSymbol) لجميع المبالغ."
        : "You are a helpful financial advisor. Always respond in English with short, practical advice. Use $currencyName ($promptSymbol) for all amounts.";

    final userPrompt = isArabic
        ? """
أنت خبير مالي. حلل هذه البيانات وأعطِ نصيحة مالية واحدة قصيرة وعملية بالعربية (جملة أو جملتين فقط):

إجمالي الدخل: $formattedIncome
إجمالي المصروفات: $formattedExpense
الصافي: $formattedNet

أعلى فئات المصروفات:
$topCategories

متطلبات:
- قصير (أقل من 150 حرف)
- عملي وقابل للتنفيذ
- بالعربية الفصحى
- استخدم $currencyName ($promptSymbol) للمبالغ
- بدون مقدمات، النصيحة فقط
"""
        : """
You are a financial expert. Analyze this data and give ONE short, practical financial advice in English (1-2 sentences only):

Total Income: $formattedIncome
Total Expenses: $formattedExpense
Net: $formattedNet

Top Expense Categories:
$topCategories

Requirements:
- Short (under 150 characters)
- Practical and actionable
- Use $currencyName ($promptSymbol) for amounts
- In English
- No introductions, just the advice
""";

    try {
      final response = await http.post(
        Uri.parse("https://openrouter.ai/api/v1/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $apiKey",
          "HTTP-Referer": "http://localhost",
          "X-Title": "Peko AI Expense Tracker",
        },
        body: jsonEncode({
          "model": "google/gemini-2.5-flash",
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userPrompt},
          ],
          "temperature": 0.7,
          "max_tokens": 150,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data["choices"]?[0]?["message"]?["content"];
        return text?.toString().trim() ??
            (isArabic ? "لم يتم الحصول على نصيحة." : "No advice received.");
      } else {
        throw Exception("Error ${response.statusCode}");
      }
    } on SocketException catch (e) {
      throw Exception(isArabic
          ? "لا يوجد اتصال بالإنترنت. سيتم المحاولة تلقائياً عند عودة الاتصال."
          : "No internet connection. Will retry automatically when connection is restored.");
    } on TimeoutException catch (e) {
      throw Exception(isArabic
          ? "انتهت مهلة الاتصال. تحقق من شبكتك."
          : "Connection timed out. Please check your network.");
    } catch (e) {
      rethrow;
    }
  }

  String _formatAmount(double amount, String symbol, bool isArabic) {
    if (isArabic) {
      return '${amount.toStringAsFixed(2)} $symbol';
    }
    final englishCode = _convertToEnglishCode(symbol);
    return '$englishCode${amount.toStringAsFixed(2)}';
  }

  String _convertToEnglishCode(String symbol) {
    final map = {
      '﷼': 'SAR', 'د.إ': 'AED', 'د.ك': 'KWD', 'د.ا': 'JOD', 'د.ب': 'BHD',
      'ر.ع': 'OMR', 'ر.ق': 'QAR', 'ل.ل': 'LBP', 'ج.م': 'EGP', 'د.ج': 'DZD',
      'د.ت': 'TND', 'م.د': 'MAD', 'ج.س': 'SDG', 'ل.س': 'SYP', 'د.ع': 'IQD',
      'ر.ي': 'YER', 'د.ل': 'LYD', '₪': 'ILS', '₺': 'TRY', '₽': 'RUB',
      '¥': 'JPY', '₩': 'KRW', '₹': 'INR',
    };
    return map[symbol] ?? symbol;
  }
}