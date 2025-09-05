import 'package:flutter/material.dart';
import '../services/sampling_service.dart';
import '../services/gemini_service.dart';
import '../services/gating_service.dart';

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
      
      // Print sampling diagnostics
      debugPrint(samplingResult.diagnostics);

      // Step 3: Analysis
      setState(() {
        _currentStep = 'Analyzing with AI...';
        _stepNumber = 3;
      });
      
      print("About to call GeminiService.analyze with ${samplingResult.framesBase64Jpeg.length} frames and ${samplingResult.snippetsBase64Mp4.length} snippets");
      final score = await GeminiService.analyze(
        framesBase64Jpeg: samplingResult.framesBase64Jpeg,
        snippetsBase64Mp4: samplingResult.snippetsBase64Mp4,
      );
      print("GeminiService.analyze returned: holistic=${score.holistic}, form=${score.form}, intensity=${score.intensity}");

      await _gating.recordAnalysisUsed();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/feedback', arguments: score);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
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

  void _showError(String error) {
    String userMessage;
    String? details;
    
    // Split error into first line and details for expandable view
    final lines = error.split('\n');
    final firstLine = lines.first;
    if (lines.length > 1) {
      details = lines.skip(1).join('\n').trim();
    }
    
    // Map specific errors to user-friendly messages
    if (error.contains('Video file not found')) {
      userMessage = "Couldn't read the video file.";
    } else if (error.contains('FFmpeg extraction produced no media')) {
      userMessage = "Couldn't extract frames/clips. Try a shorter, clearer video.";
    } else if (error.contains('GEMINI_API_KEY')) {
      userMessage = 'Missing API key. Run with --dart-define=GEMINI_API_KEY=YOUR_KEY';
    } else if (error.contains('auth error') || error.contains('401') || error.contains('403')) {
      userMessage = 'Auth error. Check your API key / Google project.';
    } else if (error.contains('PayloadTooLarge') || error.contains('413')) {
      userMessage = 'Video too large for AI. We\'ll retry with fewer frames automatically.';
    } else if (error.contains('JSON parse failed')) {
      userMessage = 'AI returned invalid JSON. Retrying…';
    } else {
      userMessage = firstLine.length > 120 ? '${firstLine.substring(0, 120)}...' : firstLine;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Analysis Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(userMessage),
              if (details != null) ...[
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Technical Details'),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        details,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
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