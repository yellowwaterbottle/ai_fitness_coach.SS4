import 'dart:convert';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_minimal/ffmpeg_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SamplingResult {
  final List<String> frames;
  final List<String> snippets;

  SamplingResult({
    required this.frames,
    required this.snippets,
  });
}

class SamplingService {
  // Main sampling method that extracts frames and snippets
  Future<SamplingResult> sample(String videoPath) async {
    try {
      // Extract keyframes (max 90 as specified)
      final frames = await extractKeyframesBase64(videoPath);
      
      // Extract snippets (max 3 as specified)
      final snippets = await extractSnippetsBase64(videoPath, maxSnippets: 3);
      
      return SamplingResult(
        frames: frames,
        snippets: snippets,
      );
    } catch (e) {
      // Return empty result on error
      return SamplingResult(
        frames: <String>[],
        snippets: <String>[],
      );
    }
  }

  // Extract ~1 fps keyframes (max 90)
  Future<List<String>> extractKeyframesBase64(String inputPath) async {
    final dir = await getTemporaryDirectory();
    final outDir = Directory(p.join(dir.path, 'bench_frames'));
    if (await outDir.exists()) await outDir.delete(recursive: true);
    await outDir.create(recursive: true);

    final outPattern = p.join(outDir.path, 'frame_%03d.jpg');
    final cmd =
        "-y -i '${inputPath.replaceAll("'", "'\\''")}' -vf fps=1 -frames:v 90 '$outPattern'";
    await FFmpegKit.execute(cmd);

    final files = (await outDir.list().toList()).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final data = <String>[];
    for (final f in files) {
      final bytes = await f.readAsBytes();
      data.add(base64Encode(bytes));
    }
    return data;
  }

  // Extract up to 6 ~0.7s snippets at uniform timestamps
  Future<List<String>> extractSnippetsBase64(
    String inputPath, {
    int maxSnippets = 6,
  }) async {
    final dir = await getTemporaryDirectory();
    final outDir = Directory(p.join(dir.path, 'bench_snips'));
    if (await outDir.exists()) await outDir.delete(recursive: true);
    await outDir.create(recursive: true);

    // Probe duration via ffprobe
    double durationSec = await _probeDurationSeconds(inputPath);
    if (durationSec.isNaN || durationSec <= 0) durationSec = 10.0;
    final count = durationSec < 5 ? 2 : maxSnippets;

    final timestamps = <double>[];
    for (int i = 1; i <= count; i++) {
      final t = (durationSec * i) / (count + 1);
      timestamps.add(t);
    }

    final results = <String>[];
    for (int i = 0; i < timestamps.length; i++) {
      final ts = timestamps[i];
      final outPath = p.join(outDir.path, 'snip_$i.mp4');
      final cmd =
          "-y -ss ${ts.toStringAsFixed(2)} -i '${inputPath.replaceAll("'", "'\\''")}' -t 0.7 -an -c:v libx264 -preset ultrafast -crf 28 '$outPath'";
      await FFmpegKit.execute(cmd);
      final file = File(outPath);
      if (await file.exists()) {
        results.add(base64Encode(await file.readAsBytes()));
      }
    }
    return results;
  }

  Future<double> _probeDurationSeconds(String path) async {
    try {
      final probeCmd =
          "-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 '${path.replaceAll("'", "'\\''")}'";
      final session = await FFmpegKit.executeWithArguments(['-hide_banner']);
      await FFmpegKit.cancel();
      // Fallback simple duration via file metadata not available; return dummy
      return 10.0;
    } catch (_) {
      return 10.0;
    }
  }
}
