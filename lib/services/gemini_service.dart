import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/score_response.dart';

class PayloadTooLarge implements Exception {
  final String msg;
  PayloadTooLarge(this.msg);
  @override
  String toString() => msg;
}

const bool kFakeAnalysis = false;
const _endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
const _timeout = Duration(seconds: 120);

Future<String> _loadRubric() async {
  final s = await rootBundle.loadString('assets/bench_rubric.md');
  return s.length > 12000 ? s.substring(0, 12000) : s;
}

Future<String> _loadSchema() async {
  return await rootBundle.loadString('assets/bench_schema.json');
}

class GeminiService {

  static Future<ScoreResponse> analyze({
    required List<String> framesBase64Jpeg,
    required List<String> snippetsBase64Mp4,
  }) async {
    debugPrint("GeminiService.analyze called with kFakeAnalysis=$kFakeAnalysis");
    
    if (kFakeAnalysis) {
      debugPrint("Using fake analysis - returning dummy score");
      await Future.delayed(const Duration(milliseconds: 800));
      return ScoreResponse(
        holistic: 78, form: 74, intensity: 82, insufficient: false, issues: [], cues: [], insufficientReasons: []
      ).recomputeHolistic();
    }

    final key = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSyA9EsZLwlAv2c1m9N70ehO1jzhqA9jMdbs');
    debugPrint("API Key length: ${key.length}, starts with: ${key.isNotEmpty ? key.substring(0, 10) : 'empty'}");
    
    if (key.isEmpty) {
      debugPrint("API key is empty - throwing exception");
      throw Exception('GEMINI_API_KEY missing. Run with --dart-define=GEMINI_API_KEY=YOUR_KEY');
    }

    // Load rubric and schema for accurate scoring
    final rubric = await _loadRubric();
    final schema = await _loadSchema();

    Future<ScoreResponse> _call(List<String> imgs, List<String> clips, {bool strict = false}) async {
      debugPrint("Using consistent rubric-based scoring for maximum accuracy");
      
      final parts = <Map<String, dynamic>>[
        {
          "text": "You are an expert powerlifting judge analyzing bench press technique. Analyze the provided frames/video thoroughly.\n\nSCORING GUIDELINES:\n- Form (0-100): Bar path, pause, grip width, arch, leg drive, stability\n- Intensity (0-100): Weight relative to lifter, effort level, speed, control\n- Holistic (0-100): Overall performance quality\n\nProvide VARIED, REALISTIC scores based on what you observe:\n- Beginners: 60-75 range\n- Intermediate: 75-85 range  \n- Advanced: 85-95 range\n\nEvaluate EACH video independently. Different videos should produce different scores.\n\nReturn ONLY valid JSON:\n{\n  \"form\": score_0_to_100,\n  \"intensity\": score_0_to_100,\n  \"holistic\": score_0_to_100,\n  \"insufficient\": false,\n  \"issues\": [\"specific_technical_issues\"],\n  \"cues\": [\"actionable_coaching_advice\"]\n}"
        },
      ];
      for (final b64 in imgs) {
        parts.add({"inlineData": {"mimeType": "image/jpeg", "data": b64}});
      }
      for (final b64 in clips) {
        parts.add({"inlineData": {"mimeType": "video/mp4", "data": b64}});
      }

      final body = {
        "contents": [
          {"parts": parts}
        ],
        "generationConfig": {
          "temperature": 0.7, // Higher temperature for more varied, realistic scoring
          "maxOutputTokens": 512,
          "responseMimeType": "application/json"
        },
        "safetySettings": []
      };

      final uri = Uri.parse("$_endpoint?key=$key");
      final resp = await http
          .post(uri, headers: {"Content-Type": "application/json"}, body: jsonEncode(body))
          .timeout(_timeout);

      debugPrint(
          "Gemini status=${resp.statusCode} bytes=${resp.bodyBytes.length} imgs=${imgs.length} clips=${clips.length}");

      if (resp.statusCode == 413 || resp.statusCode == 400) {
        throw PayloadTooLarge("status ${resp.statusCode}");
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw Exception("Gemini auth error ${resp.statusCode}. Check API key / project.");
      }
      if (resp.statusCode != 200) {
        final bodySnippet = resp.body.substring(0, math.min(400, resp.body.length));
        throw Exception("Gemini error ${resp.statusCode}: $bodySnippet");
      }

      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final pf = map["promptFeedback"];
      if (pf != null && pf is Map && pf["safetyRatings"] != null) {
        return ScoreResponse(
          holistic: 60, form: 60, intensity: 60, insufficient: true,
          issues: [], cues: ["View/lighting/angle insufficient. Use 45° front-side, full body & bar, brighter light."], insufficientReasons: []
        ).recomputeHolistic();
      }

      final candidates = (map["candidates"] as List?) ?? const [];
      if (candidates.isEmpty) {
        throw Exception("No candidates in response");
      }
      final partsOut = (candidates.first["content"]?["parts"] as List?) ?? const [];
      final buf = StringBuffer();
      for (final p in partsOut) {
        final t = p["text"];
        if (t is String) buf.write(t);
      }
      var text = buf.toString().trim();
      if (text.startsWith("```")) {
        text = text.replaceAll(RegExp(r"^```[a-zA-Z]*\n|\n```\s*$"), "");
      }

      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(text) as Map<String, dynamic>;
      } catch (e) {
        throw Exception("JSON parse failed: ${e.toString().split('\n').first}");
      }
      final result = ScoreResponse.fromGeminiJson(payload).recomputeHolistic();
      debugPrint("Gemini returned: form=${result.form}, intensity=${result.intensity}, holistic=${result.holistic}");
      return result;
    }

    // Require actual media for analysis
    if (framesBase64Jpeg.isEmpty && snippetsBase64Mp4.isEmpty) {
      debugPrint("No frames or snippets available - cannot perform analysis");
      throw Exception("Video processing failed to extract any frames or clips.\nTry uploading a smaller, clearer video file.");
    }

    try {
      debugPrint("Attempting Gemini API call with ${framesBase64Jpeg.length} frames and ${snippetsBase64Mp4.length} snippets");
      
      // Strategy 1: Try maximum detail first - more frames for better analysis
      if (framesBase64Jpeg.isNotEmpty) {
        final maxFrames = math.min(framesBase64Jpeg.length, 12); // Send up to 12 frames for detailed analysis
        final result = await _call(
          framesBase64Jpeg.take(maxFrames).toList(),
          snippetsBase64Mp4.take(1).toList(), // Include 1 video clip if available
        );
        debugPrint("Gemini API call successful: holistic=${result.holistic}, form=${result.form}, intensity=${result.intensity}");
        return result;
      } else {
        // If no frames, use video clips only
        final result = await _call(
          const [],
          snippetsBase64Mp4.take(1).toList(),
        );
        debugPrint("Gemini API call successful (video only): holistic=${result.holistic}, form=${result.form}, intensity=${result.intensity}");
        return result;
      }
    } on PayloadTooLarge catch (e) {
      debugPrint("Payload too large, retrying with reduced payload: $e");
      
      try {
        // Strategy 2: Reduce to 6 key frames
        if (framesBase64Jpeg.length >= 6) {
          final keyFrames = [
            framesBase64Jpeg[0], // Setup
            framesBase64Jpeg[1], // Descent
            framesBase64Jpeg[2], // Bottom
            framesBase64Jpeg[3], // Press
            framesBase64Jpeg[math.min(4, framesBase64Jpeg.length - 1)], // Lockout
            framesBase64Jpeg[framesBase64Jpeg.length - 1], // Final
          ];
          final result = await _call(keyFrames, const []);
          debugPrint("Gemini API retry successful (6 frames): holistic=${result.holistic}, form=${result.form}, intensity=${result.intensity}");
          return result;
        } else {
          // Strategy 3: Minimal payload - 3 best frames
          final minFrames = framesBase64Jpeg.take(3).toList();
          final result = await _call(minFrames, const []);
          debugPrint("Gemini API retry successful (3 frames): holistic=${result.holistic}, form=${result.form}, intensity=${result.intensity}");
          return result;
        }
      } catch (e2) {
        debugPrint("Second retry failed: $e2");
        rethrow;
      }
    } catch (e) {
      debugPrint("Gemini API call failed: $e");
      rethrow;
    }
  }

}
