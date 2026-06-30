import 'package:flutter/material.dart';
import 'package:currency_picker/currency_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart'; // ⬅️ تأكد من الـ import
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency_model.dart';
import '../providers/currency_provider.dart';
import '../routes/app_router.dart';

class CurrencySelectionScreen extends StatefulWidget {
  final bool isFirstTime;

  const CurrencySelectionScreen({
    super.key,
    this.isFirstTime = true,
  });

  @override
  State<CurrencySelectionScreen> createState() => _CurrencySelectionScreenState();
}

class _CurrencySelectionScreenState extends State<CurrencySelectionScreen> {
  CurrencyModel? _selectedCurrency;
  bool _isLoading = false;

  static const List<CurrencyModel> _popularCurrencies = [
    CurrencyModel(code: 'EGP', name: 'Egyptian Pound', symbol: 'E£', flag: '🇪🇬', decimalDigits: 2),
    CurrencyModel(code: 'USD', name: 'US Dollar', symbol: '\$', flag: '🇺🇸', decimalDigits: 2),
    CurrencyModel(code: 'EUR', name: 'Euro', symbol: '€', flag: '🇪🇺', decimalDigits: 2),
    CurrencyModel(code: 'GBP', name: 'British Pound', symbol: '£', flag: '🇬🇧', decimalDigits: 2),
    CurrencyModel(code: 'SAR', name: 'Saudi Riyal', symbol: '﷼', flag: '🇸🇦', decimalDigits: 2),
    CurrencyModel(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', flag: '🇦🇪', decimalDigits: 2),
    CurrencyModel(code: 'KWD', name: 'Kuwaiti Dinar', symbol: 'د.ك', flag: '🇰🇼', decimalDigits: 3),
    CurrencyModel(code: 'QAR', name: 'Qatari Riyal', symbol: '﷼', flag: '🇶🇦', decimalDigits: 2),
    CurrencyModel(code: 'JOD', name: 'Jordanian Dinar', symbol: 'د.ا', flag: '🇯🇴', decimalDigits: 3),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              if (!widget.isFirstTime)
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                ),

              const SizedBox(height: 16),

              // Title
              Text(
                'Select Your Currency',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Choose the currency you use for your daily expenses',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 20),

              // Popular Currencies Grid
              Text(
                'Popular Currencies',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              // ⬅️ FIXED: Expanded GridView بدون overflow
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.3, // ⬅️ زودت الـ ratio عشان مفيش overflow
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _popularCurrencies.length,
                  itemBuilder: (context, index) {
                    final currency = _popularCurrencies[index];
                    final isSelected = _selectedCurrency?.code == currency.code;
                    return _buildCurrencyCard(currency, isSelected);
                  },
                ),
              ),

              // "More Currencies" Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showFullCurrencyPicker,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('More Currencies'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Selected Currency Preview
              if (_selectedCurrency != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedCurrency!.flag,
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedCurrency!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_selectedCurrency!.code} • ${_selectedCurrency!.symbol}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedCurrency != null && !_isLoading
                      ? _onContinue
                      : null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(
                    widget.isFirstTime ? 'Continue' : 'Save',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyCard(CurrencyModel currency, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCurrency = currency),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        // ⬅️ FIXED: استخدمت FittedBox و Column مع MainAxisAlignment.center
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currency.flag,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(height: 6),
                Text(
                  currency.code,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                Text(
                  currency.symbol,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullCurrencyPicker() {
    showCurrencyPicker(
      context: context,
      showFlag: true,
      showCurrencyName: true,
      showCurrencyCode: true,
      onSelect: (Currency currency) {
        setState(() {
          _selectedCurrency = CurrencyModel(
            code: currency.code,
            name: currency.name,
            symbol: currency.symbol,
            flag: currency.flag ?? '',
            decimalDigits: currency.decimalDigits ?? 2,
          );
        });
      },
      favorite: ['EGP', 'USD', 'EUR', 'SAR', 'AED'],
      theme: CurrencyPickerThemeData(
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.7,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        subtitleTextStyle: TextStyle(color: Colors.grey[600]),
      ),
    );
  }

  Future<void> _onContinue() async {
    if (_selectedCurrency == null) return;

    setState(() => _isLoading = true);

    final provider = Provider.of<CurrencyProvider>(context, listen: false);
    await provider.setCurrency(_selectedCurrency!);


    if (!mounted) return;

    if (widget.isFirstTime) {
      context.go(AppRoutes.home);
    } else {
      context.pop();
    }
  }
}