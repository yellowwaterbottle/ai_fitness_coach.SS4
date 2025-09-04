import 'dart:io';
import 'package:flutter/material.dart';
import '../services/sampling_service.dart';
import '../services/gemini_service.dart';
import '../services/gating_service.dart';
import '../models/score_response.dart';

class ProcessingScreen extends StatefulWidget {
  static const routeName = '/processing';
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final SamplingService _sampler = SamplingService();
  final GatingService _gating = GatingService();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _process);
  }

  Future<void> _process() async {
    final path = ModalRoute.of(context)!.settings.arguments as String;
    // Gating: free users 1/day
    // Note: premium bypass handled in FeedbackScreen using RevenueCat
    final canFree = await _gating.canAnalyzeFreeUser();
    if (!canFree) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/paywall');
      return;
    }

    final frames = await _sampler.extractKeyframesBase64(path);
    final snippets = await _sampler.extractSnippetsBase64(path);

    // Call Gemini
    final gemini = GeminiService(
      apiKey: Platform.environment['GEMINI_API_KEY'] ?? 'YOUR_API_KEY',
    );
    ScoreResponse? score = await gemini.analyze(
      base64Frames: frames,
      base64Snippets: snippets,
    );

    if (score == null) {
      if (!mounted) return;
      _showRetry();
      return;
    }

    await _gating.recordAnalysisUsed();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/feedback', arguments: score);
  }

  void _showRetry() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Network or Server Issue'),
          content: const Text('Took too long or failed. Try again.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Processing (target < 10s)...'),
          ],
        ),
      ),
    );
  }
}
