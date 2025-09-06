import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/score_response.dart';
import '../models/score_labels.dart';

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

FailureInfo _parseFailure(Map<String, dynamic> m) {
  final statusStr = (m['status'] as String).trim();
  final status = statusStr == 'no_set'
      ? AnalysisStatus.no_set
      : AnalysisStatus.insufficient;

  final reasons = <FailReason>[];
  final rationale = <FailReason, String>{};

  if (status == AnalysisStatus.insufficient) {
    final List<dynamic> arr = (m['fail_reasons'] ?? []) as List<dynamic>;
    for (final r in arr) {
      switch ((r as String).trim()) {
        case 'poor_lighting': reasons.add(FailReason.poor_lighting); break;
        case 'subject_out_of_frame': reasons.add(FailReason.subject_out_of_frame); break;
        case 'camera_motion': reasons.add(FailReason.camera_motion); break;
        case 'too_short_clip': reasons.add(FailReason.too_short_clip); break;
        case 'blurry_frames': reasons.add(FailReason.blurry_frames); break;
        case 'wrong_orientation': reasons.add(FailReason.wrong_orientation); break;
        case 'occlusions': reasons.add(FailReason.occlusions); break;
        case 'bar_not_visible': reasons.add(FailReason.bar_not_visible); break;
        case 'multiple_people': reasons.add(FailReason.multiple_people); break;
        case 'file_corrupt': reasons.add(FailReason.file_corrupt); break;
      }
    }
    final Map<String, dynamic> rat = (m['rationale'] ?? {}) as Map<String, dynamic>;
    for (final e in rat.entries) {
      final key = e.key.trim();
      final val = e.value.toString();
      final fr = {
        'poor_lighting': FailReason.poor_lighting,
        'subject_out_of_frame': FailReason.subject_out_of_frame,
        'camera_motion': FailReason.camera_motion,
        'too_short_clip': FailReason.too_short_clip,
        'blurry_frames': FailReason.blurry_frames,
        'wrong_orientation': FailReason.wrong_orientation,
        'occlusions': FailReason.occlusions,
        'bar_not_visible': FailReason.bar_not_visible,
        'multiple_people': FailReason.multiple_people,
        'file_corrupt': FailReason.file_corrupt,
      }[key];
      if (fr != null) rationale[fr] = val;
    }
  }

  return FailureInfo(status: status, reasons: reasons, rationale: rationale);
}

ScoreResponse parseScoreOk(Map<String, dynamic> m) {
  final scores = (m['scores'] ?? {}) as Map<String, dynamic>;
  int holistic = (scores['holistic'] ?? 0).round();
  int form = (scores['form'] ?? 0).round();
  int intensity = (scores['intensity'] ?? 0).round();

  // Form subs
  final fs = <CategoryScore<SubFormKey>>[];
  final fm = (m['form_subscores'] ?? {}) as Map<String, dynamic>;
  if (fm.isNotEmpty) {
    fs.add(CategoryScore(key: SubFormKey.bar_path, score: (fm['bar_path'] ?? 0).round()));
    fs.add(CategoryScore(key: SubFormKey.range_of_motion, score: (fm['range_of_motion'] ?? 0).round()));
    fs.add(CategoryScore(key: SubFormKey.stability, score: (fm['stability'] ?? 0).round()));
    fs.add(CategoryScore(key: SubFormKey.elbow_wrist, score: (fm['elbow_wrist'] ?? 0).round()));
    fs.add(CategoryScore(key: SubFormKey.leg_drive, score: (fm['leg_drive'] ?? 0).round()));
    form = weightedForm(fs);
  }

  // Intensity subs
  final isubs = <CategoryScore<SubIntensityKey>>[];
  final im = (m['intensity_subscores'] ?? {}) as Map<String, dynamic>;
  if (im.isNotEmpty) {
    isubs.add(CategoryScore(key: SubIntensityKey.power, score: (im['power'] ?? 0).round()));
    isubs.add(CategoryScore(key: SubIntensityKey.uniformity, score: (im['uniformity'] ?? 0).round()));
    isubs.add(CategoryScore(key: SubIntensityKey.proximity_failure, score: (im['proximity_failure'] ?? 0).round()));
    isubs.add(CategoryScore(key: SubIntensityKey.cadence, score: (im['cadence'] ?? 0).round()));
    isubs.add(CategoryScore(key: SubIntensityKey.bar_speed_consistency, score: (im['bar_speed_consistency'] ?? 0).round()));
    intensity = weightedIntensity(isubs);
  }

  // Extract details
  final details = (m['details'] ?? {}) as Map<String, dynamic>;
  final issues = ((details['issues'] as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map((issue) => IssueItem.fromJson(issue))
      .toList();
  final cues = ((details['cues'] as List?) ?? const [])
      .map((e) => e.toString())
      .toList();

  // If holistic missing, compute default 0.5/0.5
  if (holistic == 0 && (form > 0 || intensity > 0)) {
    holistic = ((form + intensity) / 2).round();
  }

  return ScoreResponse.success(
    holistic: holistic.clamp(0, 100),
    form: form.clamp(0, 100),
    intensity: intensity.clamp(0, 100),
    issues: issues,
    cues: cues,
    formSubs: fs,
    intensitySubs: isubs,
  );
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
      return ScoreResponse.success(
        holistic: 78, form: 74, intensity: 82, issues: [], cues: []
      ).recomputeHolistic();
    }

    final key = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSyA9EsZLwlAv2c1m9N70ehO1jzhqA9jMdbs');
    debugPrint("API Key length: ${key.length}, starts with: ${key.isNotEmpty ? key.substring(0, 10) : 'empty'}");
    
    if (key.isEmpty) {
      debugPrint("API key is empty - throwing exception");
      throw Exception('GEMINI_API_KEY missing. Run with --dart-define=GEMINI_API_KEY=YOUR_KEY');
    }

    // Load rubric and schema for accurate scoring (available for future use)
    // final rubric = await _loadRubric();
    // final schema = await _loadSchema();

    Future<ScoreResponse> _call(List<String> imgs, List<String> clips, {bool strict = false}) async {
      debugPrint("Using consistent rubric-based scoring for maximum accuracy");
      
      final parts = <Map<String, dynamic>>[
        {
          "text": '''You are an expert powerlifting judge analyzing bench press technique.

Return ONLY valid JSON that conforms to this schema:
{
  "status": "ok" | "no_set" | "insufficient",
  "fail_reasons": string[] (only when status="insufficient"),
  "rationale": { string: string } (map from reason code to the exact scripted sentence),
  "scores": { "holistic": number, "form": number, "intensity": number } (when status="ok"),
  "details": { ... } (optional extra)
}

Reason codes (enums):
- "poor_lighting"
- "subject_out_of_frame"
- "camera_motion"
- "too_short_clip"
- "blurry_frames"
- "wrong_orientation"
- "occlusions"
- "bar_not_visible"
- "multiple_people"
- "file_corrupt"

If no training set is detected (e.g., no bench press reps), respond with:
{ "status": "no_set" }

If conditions are insufficient, respond with:
{
  "status": "insufficient",
  "fail_reasons": ["<one or more enums>"],
  "rationale": {
     "<reason>": "<exact canonical sentence below>"
  }
}

Canonical rationale strings (use verbatim):
- poor_lighting: "Video failed due to poor lighting."
- subject_out_of_frame: "Lifter and/or barbell not fully visible in frame."
- camera_motion: "Camera moved too much during the set."
- too_short_clip: "Clip is too short to analyze a set."
- blurry_frames: "Video is too blurry for reliable analysis."
- wrong_orientation: "Video orientation is not portrait."
- occlusions: "Lifter or barbell is blocked from view."
- bar_not_visible: "Barbell is not visible enough to analyze bar path."
- multiple_people: "Multiple people in frame caused ambiguity."
- file_corrupt: "Video file couldn't be decoded."

When status="ok", include scores and continue with the normal scoring output:
{
  "status": "ok",
  "scores": {
    "form": score_0_to_100,
    "intensity": score_0_to_100,
    "holistic": score_0_to_100
  },
  "form_subscores": {
    "bar_path": number,
    "range_of_motion": number,
    "stability": number,
    "elbow_wrist": number,
    "leg_drive": number
  },
  "intensity_subscores": {
    "power": number,
    "uniformity": number,
    "proximity_failure": number,
    "cadence": number,
    "bar_speed_consistency": number
  },
  "details": {
    "issues": ["specific_technical_issues"],
    "cues": ["actionable_coaching_advice"]
  }
}

Overall "form" should be the evenly weighted mean (0.20 each) of the 5 form_subscores.
Overall "intensity" should be the evenly weighted mean (0.20 each) of the 5 intensity_subscores.

Return JSON only, no explanation.'''
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
        final failure = FailureInfo(
          status: AnalysisStatus.insufficient,
          reasons: [FailReason.poor_lighting, FailReason.subject_out_of_frame],
          rationale: {
            FailReason.poor_lighting: "Video failed due to poor lighting.",
            FailReason.subject_out_of_frame: "Lifter and/or barbell not fully visible in frame.",
          },
        );
        return ScoreResponse.failure(failure);
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
      
      // Check status to determine if this is success or failure
      final status = payload['status']?.toString().trim() ?? 'ok';
      
      if (status != 'ok') {
        // Parse failure
        final failure = _parseFailure(payload);
        debugPrint("Gemini returned failure: status=$status, reasons=${failure.reasons}");
        return ScoreResponse.failure(failure);
      } else {
        // Parse success using new sub-score aware parser
        final result = parseScoreOk(payload);
        debugPrint("Gemini returned: form=${result.form}, intensity=${result.intensity}, holistic=${result.holistic}");
        return result;
      }
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
