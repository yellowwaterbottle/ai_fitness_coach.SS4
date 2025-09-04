import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static const String entitlementId = 'premium_full_access';

  static Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.warn);
    const apiKey = 'appl_test_revenuecat_api_key'; // placeholder
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  static Future<bool> isPremium() async {
    final customerInfo = await Purchases.getCustomerInfo();
    return customerInfo.entitlements.active.containsKey(entitlementId);
  }

  static Future<bool> purchasePackage(Package pkg) async {
    try {
      await Purchases.purchasePackage(pkg);
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementId);
    } catch (_) {
      return false;
    }
  }
}
