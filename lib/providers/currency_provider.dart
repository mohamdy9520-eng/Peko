// providers/currency_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency_model.dart';

class CurrencyProvider extends ChangeNotifier {
  CurrencyModel _selectedCurrency = CurrencyModel.defaultCurrency;
  bool _isLoading = true;

  CurrencyModel get selectedCurrency => _selectedCurrency;
  bool get isLoading => _isLoading;

  // ─── Quick Getters ─────────────────────────────────────────────────────
  String get symbol => _selectedCurrency.symbol;
  String get flag => _selectedCurrency.flag;
  String get code => _selectedCurrency.code;
  String get name => _selectedCurrency.name;
  int get decimalDigits => _selectedCurrency.decimalDigits;

  // ✅ NEW: Conversion rate (fallback to 1.0)
  double get rate => _selectedCurrency.rate ?? 1.0;

  CurrencyProvider() {
    _loadCurrency();
  }

  // ─── All Supported Currencies ────────────────────────────────────────
  // ✅ NEW: Static list for ChangeCurrencyScreen
  static const List<CurrencyModel> allCurrencies = [
    CurrencyModel(code: 'USD', name: 'US Dollar', symbol: r'$', arabicSymbol: r'$', flag: '🇺🇸', decimalDigits: 2, rate: 1.0),
    CurrencyModel(code: 'EUR', name: 'Euro', symbol: '€', arabicSymbol: '€', flag: '🇪🇺', decimalDigits: 2, rate: 0.92),
    CurrencyModel(code: 'GBP', name: 'British Pound', symbol: '£', arabicSymbol: '£', flag: '🇬🇧', decimalDigits: 2, rate: 0.79),
    CurrencyModel(code: 'EGP', name: 'Egyptian Pound', symbol: 'E£', arabicSymbol: 'ج.م', flag: '🇪🇬', decimalDigits: 2, rate: 30.90),
    CurrencyModel(code: 'SAR', name: 'Saudi Riyal', symbol: '﷼', arabicSymbol: 'ر.س', flag: '🇸🇦', decimalDigits: 2, rate: 3.75),
    CurrencyModel(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', arabicSymbol: 'د.إ', flag: '🇦🇪', decimalDigits: 2, rate: 3.67),
    CurrencyModel(code: 'QAR', name: 'Qatari Riyal', symbol: '﷼', arabicSymbol: 'ر.ق', flag: '🇶🇦', decimalDigits: 2, rate: 3.64),
    CurrencyModel(code: 'KWD', name: 'Kuwaiti Dinar', symbol: 'د.ك', arabicSymbol: 'د.ك', flag: '🇰🇼', decimalDigits: 3, rate: 0.31),
    CurrencyModel(code: 'JOD', name: 'Jordanian Dinar', symbol: 'د.ا', arabicSymbol: 'د.ا', flag: '🇯🇴', decimalDigits: 3, rate: 0.71),
    CurrencyModel(code: 'TRY', name: 'Turkish Lira', symbol: '₺', arabicSymbol: '₺', flag: '🇹🇷', decimalDigits: 2, rate: 32.50),
    CurrencyModel(code: 'INR', name: 'Indian Rupee', symbol: '₹', arabicSymbol: '₹', flag: '🇮🇳', decimalDigits: 2, rate: 83.12),
    CurrencyModel(code: 'PKR', name: 'Pakistani Rupee', symbol: '₨', arabicSymbol: '₨', flag: '🇵🇰', decimalDigits: 2, rate: 278.50),
  ];


  // ─── Load from SharedPreferences ─────────────────────────────────────
  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('selected_currency_code');

    if (savedCode != null) {
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
        rate: prefs.getDouble('selected_currency_rate'),
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Save Currency ────────────────────────────────────────────────────
  Future<void> setCurrency(CurrencyModel currency) async {
    _selectedCurrency = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_currency_code', currency.code);
    await prefs.setString('selected_currency_symbol', currency.symbol);
    await prefs.setString('selected_currency_arabicSymbol', currency.arabicSymbol ?? '');
    await prefs.setString('selected_currency_name', currency.name);
    await prefs.setString('selected_currency_flag', currency.flag);
    await prefs.setInt('selected_currency_digits', currency.decimalDigits);
    await prefs.setDouble('selected_currency_rate', currency.rate ?? 1.0);
    await prefs.setBool('has_selected_currency', true);
    notifyListeners();
  }

  // ─── NEW: Convert amount from USD to selected currency ──────────────
  double convert(double amountInUSD) {
    return amountInUSD * rate;
  }

  // ─── NEW: Convert amount from selected currency to USD ──────────────
  double convertToUSD(double amountInLocal) {
    return amountInLocal / rate;
  }

  // ─── Symbol by Language ─────────────────────────────────────────────
  String getSymbol(String language) {
    return _selectedCurrency.getLocalizedSymbol(language);
  }

  // ─── Format Methods (Enhanced) ──────────────────────────────────────
  String formatAmount(double amount, {String language = 'en'}) {
    final symbol = _selectedCurrency.getLocalizedSymbol(language);
    final formatted = amount.toStringAsFixed(_selectedCurrency.decimalDigits);
    return '$symbol $formatted';
  }

  String formatAmountCompact(double amount, {String language = 'en'}) {
    final symbol = _selectedCurrency.getLocalizedSymbol(language);
    final formatted = amount.toStringAsFixed(_selectedCurrency.decimalDigits);
    return '$symbol$formatted';
  }

  String formatAmountWithFlag(double amount, {String language = 'en'}) {
    final symbol = _selectedCurrency.getLocalizedSymbol(language);
    final formatted = amount.toStringAsFixed(_selectedCurrency.decimalDigits);
    return '${_selectedCurrency.flag} $symbol $formatted';
  }

  // ✅ NEW: Format USD amount converted to local currency
  String formatConverted(double amountInUSD, {String language = 'en'}) {
    final converted = convert(amountInUSD);
    return formatAmountCompact(converted, language: language);
  }

  // ✅ NEW: Format with full name
  String formatWithName(double amount, {String language = 'en'}) {
    final symbol = _selectedCurrency.getLocalizedSymbol(language);
    final formatted = amount.toStringAsFixed(_selectedCurrency.decimalDigits);
    return '$formatted $symbol (${_selectedCurrency.name})';
  }
}