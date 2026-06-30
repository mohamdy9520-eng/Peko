class CurrencyModel {
  final String code;
  final String name;
  final String symbol;
  final String flag;
  final int decimalDigits;

  const CurrencyModel({
    required this.code,
    required this.name,
    required this.symbol,
    required this.flag,
    required this.decimalDigits,
  });

  static const CurrencyModel defaultCurrency = CurrencyModel(
    code: 'EGP',
    name: 'Egyptian Pound',
    symbol: '£',
    flag: '🇪🇬',
    decimalDigits: 2,
  );

  @override
  String toString() => '$code - $name';
}