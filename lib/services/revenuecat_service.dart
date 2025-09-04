import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static const bool kRevenueCatEnabled = false; // Disabled for MVP
  static const String entitlementId = 'premium_full_access';

  static Future<void> init() async {
    if (!kRevenueCatEnabled) {
      return; // No-op when disabled
    }
    
    await Purchases.setLogLevel(LogLevel.warn);
    const apiKey = 'appl_test_revenuecat_api_key'; // placeholder
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  static Future<bool> isPremium() async {
    if (!kRevenueCatEnabled) {
      return false; // Always free when disabled
    }
    
    final customerInfo = await Purchases.getCustomerInfo();
    return customerInfo.entitlements.active.containsKey(entitlementId);
  }

  static Future<bool> purchasePackage(Package pkg) async {
    if (!kRevenueCatEnabled) {
      return false; // No purchases when disabled
    }
    
    try {
      await Purchases.purchasePackage(pkg);
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementId);
    } catch (_) {
      return false;
    }
  }
}
