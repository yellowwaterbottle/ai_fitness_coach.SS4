import 'package:flutter/material.dart';
import '../services/sampling_service.dart';
import '../services/gemini_service.dart';
import '../services/gating_service.dart';
import '../ui/style.dart';
import '../widgets/animated_gradient_square.dart';

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
  bool _isAnalyzing = true;
  String? _errorMsg;

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
        setState(() {
          _isAnalyzing = false;
          _errorMsg = 'Daily limit reached. Upgrade to Premium for unlimited analyses.';
        });
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
      
      // Route based on success/failure
      if (!score.success && score.failure != null) {
        Navigator.of(context).pushReplacementNamed('/scorecard_failed', arguments: score.failure);
      } else {
        Navigator.of(context).pushReplacementNamed('/feedback', arguments: score);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMsg = e.toString();
      });
    }
  }

  void _cancelIfSupported() {
    // For now, just navigate back - in future could cancel in-flight requests
    Navigator.of(context).pop();
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
    final loading = _isAnalyzing;
    return Container(
      decoration: const BoxDecoration(gradient: AppStyle.pageBg),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            alignment: Alignment.center,
            children: [
              if (loading) ...[
                // Soft glow behind the square
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.30,
                  child: Container(
                    width: 320, height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0x335EEAD4), blurRadius: 90, spreadRadius: 12),
                        BoxShadow(color: const Color(0x337C3AED), blurRadius: 60, spreadRadius: 8),
                      ],
                    ),
                  ),
                ),
                // Rotating gradient square (no logo)
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.28,
                  child: const AnimatedGradientSquare(size: 220, strokeWidth: 2.5),
                ),
                // Label text
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.20,
                  child: Text(
                    "Analyzing your form…",
                    style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                  ),
                ),
              ],

              // --- Optional: show small step hint or cancel ---
              Positioned(
                top: 12, left: 12,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: loading ? _cancelIfSupported : () => Navigator.pop(context),
                  tooltip: loading ? "Cancel analysis" : "Back",
                ),
              ),

              // If you show errors, overlay a card here when state == error
              if (_errorMsg != null) _ErrorCard(msg: _errorMsg!, onBack: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String msg; 
  final VoidCallback onBack;
  const _ErrorCard({required this.msg, required this.onBack});
  
  @override
  Widget build(BuildContext context) {
    String userMessage;
    String? details;
    
    // Split error into first line and details for expandable view
    final lines = msg.split('\n');
    final firstLine = lines.first;
    if (lines.length > 1) {
      details = lines.skip(1).join('\n').trim();
    }
    
    // Map specific errors to user-friendly messages
    if (msg.contains('Video file not found')) {
      userMessage = "Couldn't read the video file.";
    } else if (msg.contains('FFmpeg extraction produced no media')) {
      userMessage = "Couldn't extract frames/clips. Try a shorter, clearer video.";
    } else if (msg.contains('GEMINI_API_KEY')) {
      userMessage = 'Missing API key. Run with --dart-define=GEMINI_API_KEY=YOUR_KEY';
    } else if (msg.contains('auth error') || msg.contains('401') || msg.contains('403')) {
      userMessage = 'Auth error. Check your API key / Google project.';
    } else if (msg.contains('PayloadTooLarge') || msg.contains('413')) {
      userMessage = 'Video too large for AI. We\'ll retry with fewer frames automatically.';
    } else if (msg.contains('JSON parse failed')) {
      userMessage = 'AI returned invalid JSON. Retrying…';
    } else if (msg.contains('Daily limit reached')) {
      userMessage = 'Daily limit reached. Upgrade to Premium for unlimited analyses.';
    } else {
      userMessage = firstLine.length > 120 ? '${firstLine.substring(0, 120)}...' : firstLine;
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Material(
          color: const Color(0xFF1A2236),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Analysis failed", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(userMessage, style: const TextStyle(color: Colors.white70)),
                if (details != null) ...[
                  const SizedBox(height: 12),
                  ExpansionTile(
                    title: const Text('Technical Details', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    iconColor: Colors.white70,
                    collapsedIconColor: Colors.white70,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1220),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          details,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onBack, 
                      child: const Text("Back", style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}