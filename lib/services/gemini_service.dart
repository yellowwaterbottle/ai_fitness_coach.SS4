import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/score_response.dart';

class GeminiService {
  static const String promptVersion = '1.0.0';
  static const bool kFakeAnalysis = true; // Set to false for real analysis
  final String? apiKey;

  GeminiService({this.apiKey});

  Future<ScoreResponse?> analyze({
    required List<String> base64Frames,
    required List<String> base64Snippets,
  }) async {
    // Fake analysis mode
    if (kFakeAnalysis) {
      await Future.delayed(const Duration(seconds: 1)); // Simulate processing time
      return _getFakeScoreResponse();
    }

    // Real analysis mode
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('GEMINI_API_KEY not provided. Set kFakeAnalysis = true for testing.');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    final contentParts = <Map<String, dynamic>>[
      {
        'text':
            'PROMPT_V=$promptVersion\nexercise_type=barbell_bench_press\nReturn STRICT JSON only matching this schema: { "holistic":0-100, "form":0-100, "intensity":0-100, "issues":[{"label":"string","severity":"low|medium|high","rep_range":"string","note":"string"}], "cues":["string"], "insufficient":true|false, "insufficient_reasons":["string"] }',
      },
    ];

    for (final f in base64Frames) {
      contentParts.add({
        'inline_data': {'mime_type': 'image/jpeg', 'data': f},
      });
    }
    for (final s in base64Snippets) {
      contentParts.add({
        'inline_data': {'mime_type': 'video/mp4', 'data': s},
      });
    }

    final body = {
      'contents': [
        {'role': 'user', 'parts': contentParts},
      ],
    };

    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) return null;

    ScoreResponse? parsed = _parseGeminiResponse(resp.body);
    if (parsed == null) {
      // Retry requesting strict JSON only
      final retryBody = {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'Return valid JSON only for the same schema. No prose.'},
            ],
          },
        ],
      };
      final retry = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(retryBody),
      );
      if (retry.statusCode == 200) {
        parsed = _parseGeminiResponse(retry.body);
      }
    }
    return parsed;
  }

  ScoreResponse? _parseGeminiResponse(String body) {
    try {
      final decoded = json.decode(body);
      final candidates = decoded['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final text = candidates.first['content']['parts'].first['text'];
        return ScoreResponse.tryParseStrictJson(text);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  ScoreResponse _getFakeScoreResponse() {
    return ScoreResponse(
      holistic: 78,
      form: 74,
      intensity: 82,
      issues: [
        IssueItem(
          label: 'Elbow flare',
          severity: 'medium',
          repRange: '3–6',
          note: 'Elbows drifted >70°; tuck ~5° at bottom',
        ),
      ],
      cues: [
        'Press back then up (J-curve)',
        'Knuckles to ceiling (neutral wrists)',
        'Soft chest touch—no bounce',
      ],
      insufficient: false,
      insufficientReasons: [],
    ).copyWith(holistic: ((74 + 82) / 2).round());
  }
}
