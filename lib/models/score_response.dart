import 'dart:convert';
import 'breakdown.dart';

int _clamp01_100(num? v) {
  if (v == null || v.isNaN) return 0;
  final d = v.toDouble();
  if (d < 0) return 0;
  if (d > 100) return 100;
  return d.round();
}

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

class Issue {
  final String label;
  final String severity; // low|medium|high
  final String? repRange;
  final String? note;
  Issue({required this.label, required this.severity, this.repRange, this.note});
  factory Issue.fromJson(Map<String, dynamic> j) => Issue(
    label: (j["label"] ?? "").toString(),
    severity: (j["severity"] ?? "medium").toString(),
    repRange: j["repRange"]?.toString(),
    note: j["note"]?.toString(),
  );
}

class ScoreResponse {
  final int holistic;
  final int form;
  final int intensity;
  final List<IssueItem> issues;
  final List<String> cues;
  final bool insufficient;
  final List<String> insufficientReasons;
  final List<BreakdownItem>? formBreakdown;
  final List<BreakdownItem>? intensityBreakdown;

  ScoreResponse({
    required this.holistic,
    required this.form,
    required this.intensity,
    required this.issues,
    required this.cues,
    required this.insufficient,
    required this.insufficientReasons,
    this.formBreakdown,
    this.intensityBreakdown,
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

  static List<BreakdownItem>? _parseBreakdown(dynamic v, {bool allowCredits = true}) {
    if (v is! List) return null;
    final out = <BreakdownItem>[];
    for (final e in v) {
      if (e is Map<String, dynamic>) {
        final pts = (e['points'] is num) ? (e['points'] as num).round() : 0;
        final polStr = (e['polarity'] ?? (pts >= 0 ? 'credit' : 'penalty')).toString().toLowerCase();
        final pol = switch (polStr) {
          'penalty' => BreakdownPolarity.penalty,
          'credit' => BreakdownPolarity.credit,
          _ => BreakdownPolarity.neutral,
        };
        out.add(BreakdownItem(
          title: (e['title'] ?? e['label'] ?? '').toString(),
          note: e['note']?.toString(),
          points: pts,
          polarity: pol,
          metricKey: e['metricKey']?.toString(),
        ));
      }
    }
    return out.isEmpty ? null : out;
  }

  factory ScoreResponse.fromGeminiJson(Map<String, dynamic> j) {
    final issues = ((j["issues"] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((issue) => IssueItem.fromJson(issue))
        .toList();
    final cues = ((j["cues"] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final f = _clamp01_100(j["form"] as num?);
    final i = _clamp01_100(j["intensity"] as num?);
    final h = _clamp01_100(j["holistic"] as num?);
    final insufficientReasons = ((j["insufficient_reasons"] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    
    final formBreak = _parseBreakdown(j['formBreakdown']);
    final intBreak = _parseBreakdown(j['intensityBreakdown']);
    
    print("fromGeminiJson: raw form=${j["form"]}, raw intensity=${j["intensity"]}, raw holistic=${j["holistic"]}");
    print("fromGeminiJson: clamped form=$f, clamped intensity=$i, final holistic=$h");
    
    return ScoreResponse(
      holistic: h, form: f, intensity: i,
      insufficient: (j["insufficient"] ?? false) == true,
      issues: issues, cues: cues, insufficientReasons: insufficientReasons,
      formBreakdown: formBreak,
      intensityBreakdown: intBreak,
    );
  }

  // Method to recompute holistic score and return new instance
  ScoreResponse recomputeHolistic() {
    final h = ((form + intensity) / 2).round();
    print("recomputeHolistic: form=$form, intensity=$intensity, calculated holistic=$h");
    return copyWith(holistic: h.clamp(0, 100));
  }

  // Copy with method for updating scores
  ScoreResponse copyWith({
    int? holistic,
    int? form,
    int? intensity,
    List<IssueItem>? issues,
    List<String>? cues,
    bool? insufficient,
    List<String>? insufficientReasons,
    List<BreakdownItem>? formBreakdown,
    List<BreakdownItem>? intensityBreakdown,
  }) {
    return ScoreResponse(
      holistic: holistic ?? this.holistic,
      form: form ?? this.form,
      intensity: intensity ?? this.intensity,
      issues: issues ?? this.issues,
      cues: cues ?? this.cues,
      insufficient: insufficient ?? this.insufficient,
      insufficientReasons: insufficientReasons ?? this.insufficientReasons,
      formBreakdown: formBreakdown ?? this.formBreakdown,
      intensityBreakdown: intensityBreakdown ?? this.intensityBreakdown,
    );
  }

  // Convenience getters for percentages
  double get formPercent => (form.clamp(0,100))/100.0;
  double get intensityPercent => (intensity.clamp(0,100))/100.0;
  double get holisticPercent => (holistic.clamp(0,100))/100.0;
}

