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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Video uploaded: $fileName')),
          );
          
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
          SnackBar(content: Text('Failed to upload video: $e')),
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
        bottom: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // --- Top status chip ---
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(child: _StatusChip(ok: true)),
              ),

              // --- Center instruction text ---
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Tap to record a short video\nof your lift.",
                        textAlign: TextAlign.center,
                        style: AppStyle.title,
                      ),
                    ],
                  ),
                ),
              ),

              // --- Bottom capture area & nav ---
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 24, right: 24,
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Capture row: Upload (small) + Capture (large)
                      SizedBox(
                        height: 96,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Upload small button (right aligned per your request; choose left if preferred)
                            Positioned(
                              right: 6,
                              child: _SmallCircleButton(
                                icon: Icons.file_upload_outlined,
                                label: "Upload",
                                onTap: _onUploadPressed, // call your existing picker method
                              ),
                            ),
                            // Big capture button
                            _CaptureButton(
                              isRecording: recordingActive,
                              enabled: canRecord || recordingActive,
                              onTap: () {
                                if (recordingActive) {
                                  _stopRecording();
                                } else if (canRecord) {
                                  _startRecording();
                                } else {
                                  _showSnack("Camera not available — use Upload");
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Bottom nav
                      _BottomNav(
                        index: 0, // Scan
                        onTap: (i) {
                          // TODO: wire to your tab routing.
                          // 0 = Scan (this)
                          // 1 = Progress
                          // 2 = Coach
                          if (i == 1) Navigator.pushNamed(context, '/progress');
                          if (i == 2) Navigator.pushNamed(context, '/coach');
                        },
                      ),
                    ],
                  ),
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppStyle.chipFill,
        border: Border.all(color: AppStyle.chipBorder, width: 1),
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
    final double size = 92;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled ? AppStyle.captureGradient : const LinearGradient(colors: [Colors.grey, Colors.grey]),
          boxShadow: enabled ? AppStyle.glow : [],
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isRecording ? 28 : 44,
            height: isRecording ? 28 : 44,
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

class _SmallCircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallCircleButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: AppStyle.caption),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BottomNavigationBar(
        currentIndex: index,
        onTap: onTap,
        backgroundColor: const Color(0xFF11162A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.collections_bookmark), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Coach'),
        ],
      ),
    );
  }
}