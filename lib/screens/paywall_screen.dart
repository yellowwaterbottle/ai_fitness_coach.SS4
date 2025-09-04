import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';

class PaywallScreen extends StatefulWidget {
  static const routeName = '/paywall';
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await RevenueCatService.init();
      final offerings = await Purchases.getOfferings();
      setState(() {
        _packages = [
          ...?offerings.current?.monthly?.availablePackages,
          ...?offerings.current?.annual?.availablePackages,
        ];
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Premium unlocks:'),
            const Text('• Unlimited analyses'),
            const Text('• Full scores and cues'),
            const SizedBox(height: 16),
            if (_packages.isEmpty)
              const Center(child: CircularProgressIndicator())
            else ...[
              for (final pkg in _packages)
                ListTile(
                  title: Text(pkg.storeProduct.title),
                  subtitle: Text(pkg.storeProduct.priceString),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      final ok = await RevenueCatService.purchasePackage(pkg);
                      if (!mounted) return;
                      if (ok) Navigator.of(context).pop();
                    },
                    child: const Text('Buy'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
