import 'dart:async';
import 'dart:io';
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

class _RecordScreenState extends State<RecordScreen> {
  CameraController? _controller;
  bool _noCamera = false;
  bool _recording = false;
  DateTime? _start;
  Timer? _cap;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
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
      );
      
      await _controller!.initialize();
      setState(() {});
    } catch (e) {
      // Camera initialization failed, likely simulator
      setState(() => _noCamera = true);
    }
  }

  @override
  void dispose() {
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
      });

      // Start elapsed timer
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(_start!).inSeconds;
        });
      });

      // Auto-stop at 120 seconds
      _cap = Timer(const Duration(seconds: 120), () {
        _stopRecording();
      });
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
      
      setState(() {
        _recording = false;
        _start = null;
        _elapsedSeconds = 0;
      });

      // Navigate to processing
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/processing',
          arguments: {'videoPath': file.path},
        );
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
    final canRecord = _controller != null && _controller!.value.isInitialized && !_recording;
    final recordingActive = _recording == true;

    return Container(
      decoration: const BoxDecoration(gradient: AppStyle.pageBg),
      child: SafeArea(
        bottom: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top status chip (small and subtle)
                const SizedBox(height: 8),
                Center(child: _StatusChip(ok: true)),
                const SizedBox(height: 18),

                // Hero text
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Tap to record a short video\nof your lift.", style: AppStyle.hero, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        Text("Portrait. Full body & bar in frame.\nGood lighting helps analysis.",
                            style: AppStyle.sub, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),

                // Action area (no bottom nav)
                _ActionBar(
                  canRecord: canRecord || recordingActive,
                  recording: recordingActive,
                  onRecord: () {
                    if (recordingActive) {
                      _stopRecording();
                    } else if (canRecord) {
                      _startRecording();
                    } else {
                      _showSnack("Camera not available — try Upload Video");
                    }
                  },
                  onUpload: _onUploadPressed, // call your existing picker/upload flow
                ),
              ],
            ),
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
class _StatusChip extends StatelessWidget {
  final bool ok;
  const _StatusChip({required this.ok});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppStyle.chipFill,
        border: Border.all(color: AppStyle.chipBorder, width: 1),
        boxShadow: AppStyle.softGlow,
      ),
      child: Icon(ok ? Icons.check : Icons.info, size: 16, color: const Color(0xFF7CF29A)),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool canRecord;
  final bool recording;
  final VoidCallback onRecord;
  final VoidCallback onUpload;
  const _ActionBar({
    required this.canRecord,
    required this.recording,
    required this.onRecord,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Primary: big circular gradient record button centered
        _CaptureButton(isRecording: recording, enabled: canRecord, onTap: onRecord),
        const SizedBox(height: 16),
        // Secondary: elegant Upload pill button
        _UploadButton(onTap: onUpload),
      ],
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool isRecording;
  final bool enabled;
  final VoidCallback onTap;
  const _CaptureButton({required this.isRecording, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) {
    const double size = 108;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled ? AppStyle.captureGradient : const LinearGradient(colors: [Colors.grey, Colors.grey]),
          boxShadow: AppStyle.softGlow,
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: isRecording ? 30 : 48,
            height: isRecording ? 30 : 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isRecording ? 6 : 999),
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