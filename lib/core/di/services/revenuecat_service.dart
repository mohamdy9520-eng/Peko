import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {

  static Future<Offering?> getPremiumOffering() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.getOffering('peko_premium');
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getPaywallMetadata() async {
    final offering = await getPremiumOffering();
    return offering?.metadata;
  }

  static Future<Package?> getMonthlyPackage() async {
    final offering = await getPremiumOffering();
    return offering?.getPackage('monthly');
  }

  static Future<Package?> getYearlyPackage() async {
    final offering = await getPremiumOffering();
    return offering?.getPackage('yearly');
  }

  static Future<CustomerInfo> purchasePackage(Package package) async {
    return await Purchases.purchasePackage(package);
  }

  static Future<bool> isPremium() async {
    final customerInfo = await Purchases.getCustomerInfo();
    return customerInfo.entitlements.all['premium']?.isActive ?? false;
  }
}