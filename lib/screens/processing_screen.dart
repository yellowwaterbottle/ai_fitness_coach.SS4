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
  String _currentStep = 'Checking limits...';
  int _stepNumber = 1;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _process);
  }

  Future<void> _process() async {
    try {
      // Get video path from arguments
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final videoPath = args['videoPath'] as String;

      // Step 1: Gate check
      setState(() {
        _currentStep = 'Checking daily limits...';
        _stepNumber = 1;
      });
      
      final canFree = await _gating.canAnalyzeFreeUser();
      if (!canFree) {
        if (!mounted) return;
        _showDailyLimitReached();
        return;
      }

      // Step 2: Sampling
      setState(() {
        _currentStep = 'Extracting video samples...';
        _stepNumber = 2;
      });
      
      final samplingResult = await _sampler.sample(videoPath);

      // Step 3: Analysis
      setState(() {
        _currentStep = 'Analyzing with AI...';
        _stepNumber = 3;
      });
      
      final gemini = GeminiService();
      final score = await gemini.analyze(
        base64Frames: samplingResult.frames,
        base64Snippets: samplingResult.snippets,
      );

      if (score == null) {
        if (!mounted) return;
        _showRetry();
        return;
      }

      await _gating.recordAnalysisUsed();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/feedback', arguments: score);
    } catch (e) {
      if (!mounted) return;
      _showRetry();
    }
  }

  void _showDailyLimitReached() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Daily Limit Reached'),
          content: const Text('You\'ve used your free analysis for today. Upgrade to Premium for unlimited analyses.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/paywall');
              },
              child: const Text('Go Premium'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('Back to Record'),
            ),
          ],
        );
      },
    );
  }

  void _showRetry() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Analysis Failed'),
          content: const Text('Something went wrong during analysis. Please try again.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('Back to Record'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyzing'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Analyzing set (step $_stepNumber/3)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _currentStep,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'This may take a few moments...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}