import '../models/score_response.dart';
import '../models/breakdown.dart';

class BreakdownMapper {
  // Heuristic mapping when explicit breakdown not provided.
  static List<BreakdownItem> formFrom(ScoreResponse s) {
    // If the model already returned structured "formBreakdown", prefer it.
    if (s.formBreakdown != null && s.formBreakdown!.isNotEmpty) {
      return s.formBreakdown!;
    }
    final items = <BreakdownItem>[];

    // Map issues -> penalties
    for (final issue in s.issues) {
      final sev = (issue.severity.toLowerCase());
      final penalty = switch (sev) {
        'high' => 10,
        'medium' => 6,
        'low' => 3,
        _ => 4,
      };
      items.add(BreakdownItem(
        title: issue.label,
        note: issue.note,
        points: -penalty,
        polarity: BreakdownPolarity.penalty,
        metricKey: null,
      ));
    }

    // If too few items, add neutral credit/flags from cues
    if (items.isEmpty && s.cues.isNotEmpty) {
      for (final c in s.cues.take(3)) {
        items.add(BreakdownItem(
          title: c,
          note: null,
          points: 0,
          polarity: BreakdownPolarity.neutral,
        ));
      }
    }
    
    // If still empty, add placeholder
    if (items.isEmpty) {
      items.add(const BreakdownItem(
        title: 'Form analysis',
        note: 'No specific issues detected',
        points: 0,
        polarity: BreakdownPolarity.neutral,
      ));
    }
    
    return items;
  }

  static List<BreakdownItem> intensityFrom(ScoreResponse s) {
    if (s.intensityBreakdown != null && s.intensityBreakdown!.isNotEmpty) {
      return s.intensityBreakdown!;
    }
    final items = <BreakdownItem>[];

    // If the model added notes in cues indicating intensity, turn some into credits.
    // Heuristic: look for words indicating proximity to failure / consistency.
    for (final c in s.cues) {
      final lc = c.toLowerCase();
      if (lc.contains('consistent cadence') || lc.contains('good rom')) {
        items.add(const BreakdownItem(
          title: 'Consistent cadence / ROM',
          points: 6,
          polarity: BreakdownPolarity.credit,
        ));
      } else if (lc.contains('near failure') || lc.contains('grind')) {
        items.add(const BreakdownItem(
          title: 'Challenging final reps',
          points: 8,
          polarity: BreakdownPolarity.credit,
        ));
      }
    }

    // If still empty, add neutral placeholders so UI isn't blank
    if (items.isEmpty) {
      items.add(const BreakdownItem(
        title: 'Velocity decay',
        note: 'Derived from rep timing',
        points: 0,
        polarity: BreakdownPolarity.neutral,
      ));
      items.add(const BreakdownItem(
        title: 'Cadence stability',
        note: 'Std. dev. of rep times',
        points: 0,
        polarity: BreakdownPolarity.neutral,
      ));
    }
    return items;
  }
}
