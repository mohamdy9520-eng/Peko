import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/currency_model.dart';
import '../../providers/currency_provider.dart';


class ChangeCurrencyScreen extends StatefulWidget {
  const ChangeCurrencyScreen({super.key});

  @override
  State<ChangeCurrencyScreen> createState() => _ChangeCurrencyScreenState();
}

class _ChangeCurrencyScreenState extends State<ChangeCurrencyScreen> {
  CurrencyModel? _selectedCurrency;
  bool _isLoading = false;

  static const Color _primaryColor = Color(0xFF2E8B7B);

  static const List<CurrencyModel> _popularCurrencies = [
    CurrencyModel(code: 'EGP', name: 'Egyptian Pound', symbol: 'E£', arabicSymbol: 'ج.م', flag: '🇪🇬', decimalDigits: 2),
    CurrencyModel(code: 'USD', name: 'US Dollar', symbol: '\$', flag: '🇺🇸', decimalDigits: 2),
    CurrencyModel(code: 'EUR', name: 'Euro', symbol: '€', flag: '🇪🇺', decimalDigits: 2),
    CurrencyModel(code: 'GBP', name: 'British Pound', symbol: '£', flag: '🇬🇧', decimalDigits: 2),
    CurrencyModel(code: 'SAR', name: 'Saudi Riyal', symbol: 'SAR', arabicSymbol: '﷼', flag: '🇸🇦', decimalDigits: 2),
    CurrencyModel(code: 'AED', name: 'UAE Dirham', symbol: 'AED', arabicSymbol: 'د.إ', flag: '🇦🇪', decimalDigits: 2),
    CurrencyModel(code: 'KWD', name: 'Kuwaiti Dinar', symbol: 'KWD', arabicSymbol: 'د.ك', flag: '🇰🇼', decimalDigits: 3),
    CurrencyModel(code: 'QAR', name: 'Qatari Riyal', symbol: 'QAR', arabicSymbol: '﷼', flag: '🇶🇦', decimalDigits: 2),
    CurrencyModel(code: 'JOD', name: 'Jordanian Dinar', symbol: 'JOD', arabicSymbol: 'د.ا', flag: '🇯🇴', decimalDigits: 3),
    CurrencyModel(code: 'BHD', name: 'Bahraini Dinar', symbol: 'BHD', arabicSymbol: 'د.ب', flag: '🇧🇭', decimalDigits: 3),
    CurrencyModel(code: 'OMR', name: 'Omani Rial', symbol: 'OMR', arabicSymbol: 'ر.ع', flag: '🇴🇲', decimalDigits: 3),
    CurrencyModel(code: 'TRY', name: 'Turkish Lira', symbol: '₺', flag: '🇹🇷', decimalDigits: 2),
    CurrencyModel(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flag: '🇯🇵', decimalDigits: 0),
    CurrencyModel(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flag: '🇨🇳', decimalDigits: 2),
    CurrencyModel(code: 'INR', name: 'Indian Rupee', symbol: '₹', flag: '🇮🇳', decimalDigits: 2),
    CurrencyModel(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$', flag: '🇨🇦', decimalDigits: 2),
    CurrencyModel(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', flag: '🇦🇺', decimalDigits: 2),
    CurrencyModel(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF', flag: '🇨🇭', decimalDigits: 2),
    CurrencyModel(code: 'KRW', name: 'South Korean Won', symbol: '₩', flag: '🇰🇷', decimalDigits: 0),
    CurrencyModel(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$', flag: '🇸🇬', decimalDigits: 2),
    CurrencyModel(code: 'BRL', name: 'Brazilian Real', symbol: 'R\$', flag: '🇧🇷', decimalDigits: 2),
    CurrencyModel(code: 'ZAR', name: 'South African Rand', symbol: 'R', flag: '🇿🇦', decimalDigits: 2),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CurrencyProvider>(context, listen: false);
      setState(() => _selectedCurrency = provider.selectedCurrency);
    });
  }

  Future<void> _onSave() async {
    if (_selectedCurrency == null) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<CurrencyProvider>(context, listen: false);

      await provider.setCurrency(_selectedCurrency!);

      if (!mounted) return;

      _showSuccess('تم تغيير العملة لـ ${provider.name}');
      context.pop();
    } catch (e) {
      if (mounted) _showError('فشل الحفظ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('تغيير العملة'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedCurrency != null && _selectedCurrency!.code != currencyProvider.code)
            TextButton(
              onPressed: _isLoading ? null : _onSave,
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              Text(
                'العملة الحالية',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E8B7B), Color(0xFF4A9B8E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(currencyProvider.flag, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currencyProvider.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${currencyProvider.code} • ${currencyProvider.symbol}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'اختر عملة جديدة',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _popularCurrencies.length,
                  itemBuilder: (context, index) {
                    final currency = _popularCurrencies[index];
                    final isSelected = _selectedCurrency?.code == currency.code;
                    final isCurrent = currencyProvider.code == currency.code;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCurrency = currency),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE8F5F3)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? _primaryColor
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(currency.flag, style: TextStyle(fontSize: 28.sp)),
                            SizedBox(height: 6.h),
                            Flexible(
                              child: Text(
                                currency.code,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.sp,
                                  color: isSelected ? _primaryColor : const Color(0xFF1A1A2E),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              currency.symbol,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'الحالية',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}