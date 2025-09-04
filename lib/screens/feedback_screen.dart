import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      _premium = await RevenueCatService.isPremium();
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Large Holistic Score (always visible)
              Center(
                child: Text(
                  'Holistic: ${score.holistic}',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Form & Intensity rows
              Row(
                children: [
                  Expanded(child: _buildScoreCard('Form', score.form, !_premium)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildScoreCard('Intensity', score.intensity, !_premium)),
                ],
              ),
              const SizedBox(height: 24),
              
              if (score.insufficient) ...[
                const Text(
                  'Insufficient video for full analysis.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('Tips:'),
                const Text('• Good lighting'),
                const Text('• Full body and bar in frame'),
                const Text('• Stable phone'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Retry'),
                ),
              ] else ...[
                if (_premium) ...[
                  // Premium users see full details
                  const Text(
                    'Cues',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final c in score.cues.take(5)) 
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text('• $c'),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Issues',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final i in score.issues.take(5))
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(
                        '• ${i.label} (${i.severity}) ${i.repRange}: ${i.note}',
                      ),
                    ),
                ] else ...[
                  // Free users see unlock button
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pushNamed('/paywall'),
                      child: const Text('Unlock Premium'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('Retake'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(String label, int score, bool blur) {
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (blur) 
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
        ],
      ),
    );
  }
}