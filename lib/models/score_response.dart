import 'dart:convert';

class IssueItem {
  final String label;
  final String severity; // low|medium|high
  final String repRange;
  final String note;

  IssueItem({
    required this.label,
    required this.severity,
    required this.repRange,
    required this.note,
  });

  factory IssueItem.fromJson(Map<String, dynamic> json) {
    return IssueItem(
      label: (json['label'] ?? '').toString(),
      severity: (json['severity'] ?? '').toString(),
      repRange: (json['rep_range'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class ScoreResponse {
  final int holistic;
  final int form;
  final int intensity;
  final List<IssueItem> issues;
  final List<String> cues;
  final bool insufficient;
  final List<String> insufficientReasons;

  ScoreResponse({
    required this.holistic,
    required this.form,
    required this.intensity,
    required this.issues,
    required this.cues,
    required this.insufficient,
    required this.insufficientReasons,
  });

  static int _clampScore(num value) {
    final intVal = value.round();
    if (intVal < 0) return 0;
    if (intVal > 100) return 100;
    return intVal;
  }

  factory ScoreResponse.fromJson(Map<String, dynamic> json) {
    final form = _clampScore(json['form'] ?? 0);
    final intensity = _clampScore(json['intensity'] ?? 0);
    final holisticDeterministic = _clampScore(0.5 * form + 0.5 * intensity);

    final issues =
        (json['issues'] as List?)
            ?.map((e) => IssueItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList() ??
        <IssueItem>[];
    final cues =
        (json['cues'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];
    final insufficient = (json['insufficient'] ?? false) == true;
    final insufficientReasons =
        (json['insufficient_reasons'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    return ScoreResponse(
      holistic: holisticDeterministic,
      form: form,
      intensity: intensity,
      issues: issues,
      cues: cues,
      insufficient: insufficient,
      insufficientReasons: insufficientReasons,
    );
  }

  static ScoreResponse? tryParseStrictJson(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return ScoreResponse.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Helper method to recompute holistic score
  int get recomputeHolistic => _clampScore((form + intensity) / 2);

  // Copy with method for updating scores
  ScoreResponse copyWith({
    int? holistic,
    int? form,
    int? intensity,
    List<IssueItem>? issues,
    List<String>? cues,
    bool? insufficient,
    List<String>? insufficientReasons,
  }) {
    return ScoreResponse(
      holistic: holistic ?? this.holistic,
      form: form ?? this.form,
      intensity: intensity ?? this.intensity,
      issues: issues ?? this.issues,
      cues: cues ?? this.cues,
      insufficient: insufficient ?? this.insufficient,
      insufficientReasons: insufficientReasons ?? this.insufficientReasons,
    );
  }
}
