import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/di/services/NetworkProvider.dart';
import '../../../core/di/services/ai_insight_service.dart.dart';


class AIInsightCard extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;
  final String apiKey;

  const AIInsightCard({
    Key? key,
    required this.transactions,
    required this.apiKey,
  }) : super(key: key);

  @override
  State<AIInsightCard> createState() => _AIInsightCardState();
}

class _AIInsightCardState extends State<AIInsightCard> {
  String? _insight;
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchInsight();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NetworkProvider>().addListener(_handleNetworkChange);
    });
  }

  @override
  void dispose() {
    context.read<NetworkProvider>().removeListener(_handleNetworkChange);
    super.dispose();
  }

  void _handleNetworkChange() {
    final network = context.read<NetworkProvider>();

    if (network.isConnected && _error != null && mounted) {
      setState(() {
        _error = null;
      });
      _fetchInsight();
    }
  }

  Future<void> _fetchInsight() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = AIInsightService(apiKey: widget.apiKey);
      final result = await service.getExpenseInsight(
        widget.transactions,
        context: context,
      );

      if (mounted) {
        setState(() {
          _insight = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'النصيحة المالية' : 'AI Financial Insight',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _buildErrorWidget(isArabic)
            else if (_insight != null)
                Text(
                  _insight!,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _fetchInsight,
            icon: const Icon(Icons.refresh),
            label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
          ),
        ],
      ),
    );
  }
}