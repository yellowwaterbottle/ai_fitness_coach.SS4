import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/score_response.dart';
import '../services/revenuecat_service.dart';

class FeedbackScreen extends StatefulWidget {
  static const routeName = '/feedback';
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  bool _premium = false;
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _checkEntitlements();
  }

  Future<void> _checkEntitlements() async {
    try {
      await RevenueCatService.init();
      _premium = await RevenueCatService.isPremium();
      final offerings = await Purchases.getOfferings();
      _packages = [
        ...?offerings.current?.monthly?.availablePackages,
        ...?offerings.current?.annual?.availablePackages,
      ];
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScoreResponse score =
        ModalRoute.of(context)!.settings.arguments as ScoreResponse;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Scorecard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Holistic: ${score.holistic}',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _blurCard('Form: ${score.form}', !_premium)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _blurCard(
                      'Intensity: ${score.intensity}',
                      !_premium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (score.insufficient) ...[
                const Text('Insufficient video for full analysis.'),
                const SizedBox(height: 8),
                const Text('Tips:'),
                const Text('• Good lighting'),
                const Text('• Full body and bar in frame'),
                const Text('• Stable phone'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Retry'),
                ),
              ] else ...[
                if (_premium) ...[
                  const Text('Cues'),
                  for (final c in score.cues.take(5)) Text('• $c'),
                  const SizedBox(height: 12),
                  const Text('Issues'),
                  for (final i in score.issues)
                    Text(
                      '• ${i.label} (${i.severity}) ${i.repRange}: ${i.note}',
                    ),
                ] else ...[
                  Center(
                    child: ElevatedButton(
                      onPressed: _packages.isEmpty
                          ? _goPaywall
                          : () async {
                              final success =
                                  await RevenueCatService.purchasePackage(
                                    _packages.first,
                                  );
                              if (success && mounted) {
                                setState(() => _premium = true);
                              } else {
                                _goPaywall();
                              }
                            },
                      child: const Text('Unlock Premium'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _blurCard(String text, bool blur) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 90,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(text, style: const TextStyle(fontSize: 20)),
          ),
          if (blur) Container(color: Colors.white.withOpacity(0.75)),
        ],
      ),
    );
  }

  void _goPaywall() {
    Navigator.of(context).pushNamed('/paywall');
  }
}
