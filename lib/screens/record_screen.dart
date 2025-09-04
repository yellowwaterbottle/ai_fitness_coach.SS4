import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/gating_service.dart';

class RecordScreen extends StatefulWidget {
  static const routeName = '/';
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;
  Timer? _timer;
  int _elapsed = 0;
  String? _outputPath;
  final GatingService _gating = GatingService();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (await _gating.isOffline()) {
      if (mounted) _showOfflineDialog();
      return;
    }
    await [Permission.camera, Permission.microphone].request();
    _cameras = await availableCameras();
    final back = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
    _controller = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: true,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_controller == null || _isRecording) return;
    // Gating check in ProcessingScreen before analysis, but allow recording always while online
    final dir = await getTemporaryDirectory();
    _outputPath = p.join(
      dir.path,
      'bench_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    await _controller!.startVideoRecording();
    _isRecording = true;
    _elapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      setState(() {
        _elapsed++;
      });
      if (_elapsed >= 120) {
        await _stop();
      }
    });
    setState(() {});
  }

  Future<void> _stop() async {
    if (_controller == null || !_isRecording) return;
    _timer?.cancel();
    final file = await _controller!.stopVideoRecording();
    _isRecording = false;
    final saved = File(file.path);
    if (_outputPath != null) {
      await saved.copy(_outputPath!);
    }
    if (!mounted) return;
    // Navigate to processing
    Navigator.of(
      context,
    ).pushNamed('/processing', arguments: _outputPath ?? file.path);
  }

  void _showOfflineDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Offline'),
          content: const Text(
            'Please connect to the internet to record and analyze.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Bench Set')),
      body: Column(
        children: [
          if (_controller?.value.isInitialized == true)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            )
          else
            const Expanded(child: Center(child: CircularProgressIndicator())),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: const [
                Text(
                  'Place phone ~45°, include shoulders-to-hips and bar.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Text('Time: ${_elapsed}s (max 120s)'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isRecording ? null : _start,
                child: const Text('Start'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _isRecording ? _stop : null,
                child: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
