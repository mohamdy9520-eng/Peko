// models/currency_model.dart
class CurrencyModel {
  final String code;
  final String name;
  final String symbol; // English symbol (default)
  final String? arabicSymbol; // Arabic symbol (optional)
  final String flag;
  final int decimalDigits;

  const CurrencyModel({
    required this.code,
    required this.name,
    required this.symbol,
    this.arabicSymbol,
    required this.flag,
    required this.decimalDigits,
  });

  static const CurrencyModel defaultCurrency = CurrencyModel(
    code: 'USD',
    name: 'US Dollar',
    symbol: '\$',
    flag: '🇺🇸',
    decimalDigits: 2,
  );

  /// ✅ تعديل: بنتأكد إن arabicSymbol مش null ومش فاضي كمان
  /// (عشان لو اتخزن '' بالغلط في SharedPreferences، يرجع الرمز الإنجليزي بدل سترينج فاضي)
  String getLocalizedSymbol(String language) {
    if (language == 'ar' &&
        arabicSymbol != null &&
        arabicSymbol!.trim().isNotEmpty) {
      return arabicSymbol!;
    }
    return symbol;
  }

  factory CurrencyModel.fromJson(Map<String, dynamic> json) {
    return CurrencyModel(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
      arabicSymbol: json['arabicSymbol'],
      flag: json['flag'] ?? '',
      decimalDigits: json['decimalDigits'] ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'symbol': symbol,
      'arabicSymbol': arabicSymbol,
      'flag': flag,
      'decimalDigits': decimalDigits,
    };
  }
}
