import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency_model.dart';

class CurrencyProvider extends ChangeNotifier {
  CurrencyModel _selectedCurrency = CurrencyModel.defaultCurrency;
  bool _isLoading = true;

  CurrencyModel get selectedCurrency => _selectedCurrency;
  bool get isLoading => _isLoading;

  // ⬅️ NEW: Getters للوصول السريع
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
      _selectedCurrency = CurrencyModel(
        code: savedCode,
        name: prefs.getString('selected_currency_name') ?? savedCode,
        symbol: prefs.getString('selected_currency_symbol') ?? '',
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
    await prefs.setString('selected_currency_name', currency.name);
    await prefs.setString('selected_currency_flag', currency.flag);
    await prefs.setInt('selected_currency_digits', currency.decimalDigits);
    await prefs.setBool('has_selected_currency', true);
    notifyListeners();
  }

  /// Format amount with currency symbol (e.g., "£ 150.50")
  String formatAmount(double amount) {
    return '${_selectedCurrency.symbol} ${amount.toStringAsFixed(_selectedCurrency.decimalDigits)}';
  }

  /// Format amount with flag (e.g., "🇪🇬 £ 150.50")
  String formatAmountWithFlag(double amount) {
    return '${_selectedCurrency.flag} ${_selectedCurrency.symbol} ${amount.toStringAsFixed(_selectedCurrency.decimalDigits)}';
  }

  /// Format amount compact (e.g., "£150.50" without space)
  String formatAmountCompact(double amount) {
    return '${_selectedCurrency.symbol}${amount.toStringAsFixed(_selectedCurrency.decimalDigits)}';
  }
}