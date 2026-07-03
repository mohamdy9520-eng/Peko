// providers/currency_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency_model.dart';

class CurrencyProvider extends ChangeNotifier {
  CurrencyModel _selectedCurrency = CurrencyModel.defaultCurrency;
  bool _isLoading = true;

  CurrencyModel get selectedCurrency => _selectedCurrency;
  bool get isLoading => _isLoading;

  // Getters للوصول السريع
  // ⚠️ ملاحظة: symbol هنا بيرجع الرمز الافتراضي فقط (مش localized حسب اللغة)
  // استخدم getSymbol(language) بدل ما تستخدم symbol مباشرة في أي مكان
  // بيتأثر بتغيير اللغة (زي عرض المعاملات، الرصيد... إلخ)
  String get symbol => _selectedCurrency.symbol;
  String get flag => _selectedCurrency.flag;
  String get code => _selectedCurrency.code;
  String get name => _selectedCurrency.name;
  int get decimalDigits => _selectedCurrency.decimalDigits;

  CurrencyProvider() {
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('selected_currency_code');

    if (savedCode != null) {
      // ✅ تعديل: لو القيمة المخزنة فاضية، نرجعها null بدل ''
      final savedArabicSymbol = prefs.getString('selected_currency_arabicSymbol');
      _selectedCurrency = CurrencyModel(
        code: savedCode,
        name: prefs.getString('selected_currency_name') ?? savedCode,
        symbol: prefs.getString('selected_currency_symbol') ?? '',
        arabicSymbol: (savedArabicSymbol == null || savedArabicSymbol.trim().isEmpty)
            ? null
            : savedArabicSymbol,
        flag: prefs.getString('selected_currency_flag') ?? '',
        decimalDigits: prefs.getInt('selected_currency_digits') ?? 2,
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setCurrency(CurrencyModel currency) async {
    _selectedCurrency = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_currency_code', currency.code);
    await prefs.setString('selected_currency_symbol', currency.symbol);
    await prefs.setString('selected_currency_arabicSymbol', currency.arabicSymbol ?? ''); // ✅ جديد
    await prefs.setString('selected_currency_name', currency.name);
    await prefs.setString('selected_currency_flag', currency.flag);
    await prefs.setInt('selected_currency_digits', currency.decimalDigits);
    await prefs.setBool('has_selected_currency', true);
    notifyListeners();
  }

  /// ✅ جديد: بيرجع الرمز المناسب حسب اللغة مباشرة من الـ Provider
  /// استخدمها في أي مكان محتاج يعرض الرمز بس (زي TransactionItem)
  String getSymbol(String language) {
    return _selectedCurrency.getLocalizedSymbol(language);
  }

  /// ✅ Format amount with localized symbol
  String formatAmount(double amount, {String language = 'en'}) {
    final symbol = _selectedCurrency.getLocalizedSymbol(language);
    return '$symbol ${amount.toStringAsFixed(_selectedCurrency.decimalDigits)}';
  }

  /// ✅ Format amount compact with localized symbol
  String formatAmountCompact(double amount, {String language = 'en'}) {
    final symbol = _selectedCurrency.getLocalizedSymbol(language);
    return '$symbol${amount.toStringAsFixed(_selectedCurrency.decimalDigits)}';
  }

  /// ✅ Format amount with flag
  String formatAmountWithFlag(double amount, {String language = 'en'}) {
    final symbol = _selectedCurrency.getLocalizedSymbol(language);
    return '${_selectedCurrency.flag} $symbol ${amount.toStringAsFixed(_selectedCurrency.decimalDigits)}';
  }
}
