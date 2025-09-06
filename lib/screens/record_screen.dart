import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../ui/style.dart';

class RecordScreen extends StatefulWidget {
  static const routeName = '/';
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  late Future<void> _cameraInit;
  bool _noCamera = false;
  bool _recording = false;
  bool _controllerReady = false;
  DateTime? _start;
  Timer? _cap;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  // Progress ring for recording
  static const Duration kMaxRecordDuration = Duration(minutes: 2);     // real cap (auto-stop)
  static const Duration kProgressRingDuration = Duration(seconds: 16); // visual speed (2.5× faster than 40s)
  late AnimationController _recAnim;     // 0..1 over kProgressRingDuration
  late AnimationController _fadeAnim;    // 0..1 for fade-out at lap end (~220ms)
  double _recProgress = 0.0;
  double _ringOpacity = 1.0;
  Timer? _autoStopTimer;               // enforces 2:00 cap
  bool _animsInitialized = false;

  @override
  void initState() {
    super.initState();
    
    if (!_animsInitialized) {
      _recAnim = AnimationController(vsync: this, duration: kProgressRingDuration)
        ..addListener(() {
          if (mounted) setState(() => _recProgress = _recAnim.value);
        })
        ..addStatusListener((status) async {
          if (!mounted) return;
          if (status == AnimationStatus.completed && _recording) {
            // Start fade-out at lap end
            _fadeAnim
              ..reset()
              ..forward();
          }
        });

      _fadeAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
        ..addListener(() {
          if (mounted) setState(() => _ringOpacity = 1.0 - _fadeAnim.value);
        })
        ..addStatusListener((status) {
          if (!mounted) return;
          if (status == AnimationStatus.completed && _recording) {
            // After fade completes, reset opacity and restart a fresh lap
            _ringOpacity = 1.0;
            _recAnim
              ..reset()
              ..forward();
            setState(() {});
          }
        });

      _animsInitialized = true;
    }

    _init();
  }

  Future<void> _init() async {
    try {
      // Request permissions
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();
      
      if (cameraStatus.isDenied || micStatus.isDenied) {
        setState(() => _noCamera = true);
        return;
      }

      // Get available cameras
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _noCamera = true);
        return;
      }

      // Pick back camera (or first available)
      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      // Create and initialize controller
      _controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      
      _cameraInit = _controller!.initialize();
      await _cameraInit;
      if (!mounted) return;
      setState(() => _controllerReady = true);
    } catch (e) {
      // Camera initialization failed, likely simulator
      setState(() => _noCamera = true);
    }
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _fadeAnim.dispose();
    _recAnim.dispose();
    _cap?.cancel();
    _elapsedTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_controller == null || _recording) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _recording = true;
        _start = DateTime.now();
        _elapsedSeconds = 0;
        _ringOpacity = 1.0;
        _recProgress = 0.0;
      });
      _fadeAnim.reset();
      _recAnim
        ..reset()
        ..forward();
      // Auto-stop guard at the real 2:00 cap
      _autoStopTimer?.cancel();
      _autoStopTimer = Timer(kMaxRecordDuration, () async {
        if (mounted && _recording) {
          await _stopRecording();
        }
      });

      // Start elapsed timer
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(_start!).inSeconds;
        });
      });

      // Auto-stop handled by animation controller at 2:00 mark
    } catch (e) {
      setState(() => _recording = false);
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_recording) return;

    try {
      _cap?.cancel();
      _elapsedTimer?.cancel();
      
      final file = await _controller!.stopVideoRecording();
      
      _autoStopTimer?.cancel();
      _autoStopTimer = null;

      _recAnim.stop();
      _fadeAnim.stop();
      setState(() {
        _recording = false;
        _start = null;
        _elapsedSeconds = 0;
        _ringOpacity = 0.0;  // hide immediately on stop
        _recProgress = 0.0;
      });

      // Navigate to processing
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/processing',
          arguments: {'videoPath': file.path},
        );
        // After navigating, reset visuals:
        _recAnim.reset();
        setState(() => _recProgress = 0.0);
      }
    } catch (e) {
      setState(() => _recording = false);
    }
  }

  Future<String> _copySampleToTemp() async {
    final bytes = await rootBundle.load('assets/sample_bench.mp4');
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/sample_bench.mp4');
    await f.writeAsBytes(bytes.buffer.asUint8List());
    return f.path;
  }

  Future<void> _useSampleVideo() async {
    try {
      final path = await _copySampleToTemp();
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/processing',
          arguments: {'videoPath': path},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load sample video')),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        
        // Copy the selected file to temp directory
        final tempDir = await getTemporaryDirectory();
        final tempPath = p.join(tempDir.path, 'uploaded_$fileName');
        
        final sourceFile = File(filePath);
        final tempFile = await sourceFile.copy(tempPath);
        
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/processing',
            arguments: {'videoPath': tempFile.path},
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload video. Please try again.')),
        );
      }
    }
  }

  void _showFilmingTips() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Filming Tips'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• 45° front-side angle'),
              Text('• Full body + bar in frame'),
              Text('• Phone ~2–3m away'),
              Text('• Good lighting'),
              Text('• Keep phone stable'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRecord = _controllerReady && !_recording;
    const double kUploadButtonHeight = 52; // visual height incl. padding

    return Container(
      decoration: const BoxDecoration(gradient: AppStyle.pageBg), // fallback if preview not ready
      child: SafeArea(
        bottom: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1) Live camera fills background
              if (_controller != null)
                FutureBuilder(
                  future: _cameraInit,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.done && _controller!.value.isInitialized) {
                      return FittedBox(
                        fit: BoxFit.cover, // aspect-fill like Snapchat
                        child: SizedBox(
                          width: _controller!.value.previewSize!.height, // note: width/height swapped
                          height: _controller!.value.previewSize!.width,
                          child: CameraPreview(_controller!),
                        ),
                      );
                    }
                    return const SizedBox.shrink(); // fallback to gradient below
                  },
                ),

              // Optional: subtle vignette so overlaid text stays readable
              IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0x660E1220), Color(0x330E1220), Color(0x880E1220)],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),


              // 3) Center hero text (hide while recording)
              if (!_recording)
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Tap to record a short video\nof your lift.",
                          style: AppStyle.hero, textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Portrait. Full body & bar in frame.\nGood lighting helps analysis.",
                          style: AppStyle.sub, textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              // 4) Bottom actions: capture is fixed; we reserve space for Upload when hidden
              Positioned(
                left: 20,
                right: 20,
                // Keep a fixed bottom offset for the capture button, independent of upload visibility.
                bottom: MediaQuery.of(context).padding.bottom + 18 + kUploadButtonHeight + 14,
                child: _CaptureButton(
                  isRecording: _recording,
                  enabled: (_controllerReady && !_recording) || _recording,
                  onTap: () async {
                    if (_recording) {
                      await _stopRecording();
                    } else if (_controllerReady) {
                      await _startRecording();
                    } else {
                      _showSnack("Camera not available — try Upload Video");
                    }
                  },
                  progress: _recording ? _recProgress : 0.0,
                  ringOpacity: _ringOpacity,
                ),
              ),

              // Upload area pinned to the very bottom; when recording we keep a transparent spacer
              Positioned(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 18,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: _recording
                      ? SizedBox(height: kUploadButtonHeight) // spacer to preserve layout
                      : _UploadButton(onTap: _onUploadPressed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onUploadPressed() async {
    try {
      // Call your existing picker/upload flow
      await _uploadVideo();
    } catch (e) {
      _showSnack("Upload failed: $e");
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// --- UI Helpers ---


class _CaptureButton extends StatelessWidget {
  final bool isRecording;
  final bool enabled;
  final VoidCallback onTap;
  final double progress; // 0..1
  final double ringOpacity; // 0..1 (fades at lap end)
  const _CaptureButton({
    required this.isRecording,
    required this.enabled,
    required this.onTap,
    required this.progress,
    required this.ringOpacity,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 108.0;
    const double strokeW = 5.0;

    // We wrap the button with CustomPaint.foregroundPainter so the red arc renders ON TOP.
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          foregroundPainter: _ProgressRingPainter(
            progress: progress,
            strokeWidth: strokeW,
            color: const Color(0xFFFF4D4D).withOpacity(ringOpacity.clamp(0.0, 1.0)),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: enabled
                    ? AppStyle.captureGradient
                    : const LinearGradient(colors: [Colors.grey, Colors.grey]),
                boxShadow: AppStyle.softGlow,
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    // circle (idle) → square (stop) when recording
                    borderRadius: BorderRadius.circular(isRecording ? 8 : 999),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: AppStyle.glassCard.copyWith(
          boxShadow: AppStyle.softGlow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.file_upload_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text("Upload Video", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;    // 0..1
  final double strokeWidth;
  final Color color;
  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || color.opacity == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Start at 12 o'clock (−π/2), clockwise sweep
    final start = -math.pi / 2;
    final sweep = 2 * math.pi * progress;

    final red = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      red,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress ||
      old.strokeWidth != strokeWidth ||
      old.color != color;
}