import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/di/services/ai_access_service.dart';
import '../core/di/services/revenuecat_service.dart';

class PaywallScreen extends StatefulWidget {
  final AiBlockReason reason;

  const PaywallScreen({super.key, this.reason = AiBlockReason.none});

  @override
  _PaywallScreenState createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Package? monthlyPackage;
  Package? yearlyPackage;
  Map<String, dynamic>? metadata;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPaywallData();
  }

  Future<void> loadPaywallData() async {
    final offering = await RevenueCatService.getPremiumOffering();

    if (offering != null) {
      setState(() {
        monthlyPackage = offering.getPackage('monthly');
        yearlyPackage = offering.getPackage('yearly');

        metadata = offering.metadata;

        isLoading = false;
      });
    }
  }

  Future<void> purchase(Package package) async {
    try {
      await RevenueCatService.purchasePackage(package);
      Navigator.pop(context);
    } catch (e) {
      print('Purchase error: $e');
    }
  }

  // ✅ NEW: contextual banner explaining *why* the user landed on the paywall
  Widget _buildReasonBanner() {
    String? message;
    IconData icon = Icons.info_outline;
    Color color = Colors.amber;

    switch (widget.reason) {
      case AiBlockReason.freeLimitReached:
        message =
        "You've used all your free AI plans. Upgrade to keep getting personalized budget, savings & goals plans!";
        icon = Icons.auto_awesome;
        color = Colors.amber;
        break;
      case AiBlockReason.notAuthenticated:
        message = "Please log in to continue using AI features.";
        icon = Icons.lock_outline;
        color = Colors.red;
        break;
      case AiBlockReason.none:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final monthlyFeatures = metadata?['monthly_features'] as List<dynamic>? ?? [];
    final yearlyFeatures = metadata?['yearly_features'] as List<dynamic>? ?? [];
    final recommended = metadata?['recommended'] as String? ?? 'yearly';
    final title = metadata?['title'] as String? ?? 'Peko Premium';
    final subtitle = metadata?['subtitle'] as String? ?? 'Premium Features';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(fontSize: 16, color: Colors.blue),
              ),
              SizedBox(height: 24),

              // ✅ NEW: shows *why* the user is seeing this paywall
              _buildReasonBanner(),

              if (yearlyPackage != null)
                _buildPlanCard(
                  package: yearlyPackage!,
                  features: yearlyFeatures.cast<String>(),
                  isRecommended: recommended == 'yearly',
                  discount: 'SAVE 30%',
                ),

              SizedBox(height: 16),

              if (monthlyPackage != null)
                _buildPlanCard(
                  package: monthlyPackage!,
                  features: monthlyFeatures.cast<String>(),
                  isRecommended: recommended == 'monthly',
                ),

              Spacer(),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => purchase(
                      recommended == 'yearly' ? yearlyPackage! : monthlyPackage!
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Get Premium Access', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required Package package,
    required List<String> features,
    bool isRecommended = false,
    String? discount,
  }) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(
          color: isRecommended ? Colors.blue : Colors.grey.shade300,
          width: isRecommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: isRecommended ? Colors.blue.shade50 : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (discount != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(discount, style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          SizedBox(height: 8),

          Text(
            package.storeProduct.priceString,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          ...features.map((feature) => Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(feature),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
