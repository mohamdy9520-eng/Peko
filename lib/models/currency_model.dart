// models/currency_model.dart
class CurrencyModel {
  final String code;
  final String name;
  final String symbol;
  final String? arabicSymbol;
  final String flag;
  final int decimalDigits;
  final double? rate; // لو موجود

  const CurrencyModel({
    required this.code,
    required this.name,
    required this.symbol,
    this.arabicSymbol,
    required this.flag,
    this.decimalDigits = 2,
    this.rate,
  });

  static const CurrencyModel defaultCurrency = CurrencyModel(
    code: 'USD',
    name: 'US Dollar',
    symbol: r'$',
    flag: '🇺🇸',
    decimalDigits: 2,
    rate: 1.0,
  );

  String getLocalizedSymbol(String language) {
    if (language == 'ar' && arabicSymbol != null && arabicSymbol!.isNotEmpty) {
      return arabicSymbol!;
    }
    return symbol;
  }
}