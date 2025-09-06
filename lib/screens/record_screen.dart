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
  late Future<void> _cameraInit;
  bool _noCamera = false;
  bool _recording = false;
  bool _controllerReady = false;
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
    final canRecord = _controllerReady && !_recording;

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

              // 2) Top status chip (unchanged)
              const Positioned(
                top: 10, left: 0, right: 0,
                child: Center(child: _StatusChip(ok: true)),
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

              // 4) Bottom actions (upload hidden while recording)
              Positioned(
                left: 20, right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CaptureButton(
                      isRecording: _recording,
                      enabled: canRecord || _recording,
                      onTap: () async {
                        if (_recording) {
                          await _stopRecording();
                        } else if (canRecord) {
                          await _startRecording();
                        } else {
                          _showSnack("Camera not available — try Upload Video");
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    if (!_recording)
                      _UploadButton(onTap: _onUploadPressed),
                  ],
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          // RED RECORD RING overlay when recording
          AnimatedOpacity(
            opacity: isRecording ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: size + 18, height: size + 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF4D4D), width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x33FF4D4D), blurRadius: 22, spreadRadius: 2),
                ],
              ),
            ),
          ),
          // Gradient main button
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: enabled
                  ? AppStyle.captureGradient
                  : const LinearGradient(colors: [Colors.grey, Colors.grey]),
              boxShadow: AppStyle.softGlow,
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isRecording ? 8 : 999),
                ),
              ),
            ),
          ),
        ],
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