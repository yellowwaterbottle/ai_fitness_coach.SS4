import 'score_response.dart';

// Display labels
const Map<SubFormKey, String> kFormLabels = {
  SubFormKey.bar_path: "Bar Path",
  SubFormKey.range_of_motion: "Range of Motion",
  SubFormKey.stability: "Stability",
  SubFormKey.elbow_wrist: "Wrists & Elbow Flare",
  SubFormKey.leg_drive: "Leg Drive",
};

const Map<SubIntensityKey, String> kIntensityLabels = {
  SubIntensityKey.power: "Power",
  SubIntensityKey.uniformity: "Uniformity",
  SubIntensityKey.proximity_failure: "Proximity to Failure",
  SubIntensityKey.cadence: "Cadence",
  SubIntensityKey.bar_speed_consistency: "Bar-speed Consistency",
};

// Even weights (0.20 each)
const Map<SubFormKey, double> kFormWeights = {
  SubFormKey.bar_path: 0.20,
  SubFormKey.range_of_motion: 0.20,
  SubFormKey.stability: 0.20,
  SubFormKey.elbow_wrist: 0.20,
  SubFormKey.leg_drive: 0.20,
};

const Map<SubIntensityKey, double> kIntensityWeights = {
  SubIntensityKey.power: 0.20,
  SubIntensityKey.uniformity: 0.20,
  SubIntensityKey.proximity_failure: 0.20,
  SubIntensityKey.cadence: 0.20,
  SubIntensityKey.bar_speed_consistency: 0.20,
};

// Weighted means (integer 0..100)
int weightedForm(List<CategoryScore<SubFormKey>> items) {
  if (items.isEmpty) return 0;
  double sum = 0, w = 0;
  for (final it in items) {
    final wt = kFormWeights[it.key] ?? 0;
    sum += wt * it.score;
    w += wt;
  }
  return (w == 0 ? 0 : sum / w).round().clamp(0, 100);
}

int weightedIntensity(List<CategoryScore<SubIntensityKey>> items) {
  if (items.isEmpty) return 0;
  double sum = 0, w = 0;
  for (final it in items) {
    final wt = kIntensityWeights[it.key] ?? 0;
    sum += wt * it.score;
    w += wt;
  }
  return (w == 0 ? 0 : sum / w).round().clamp(0, 100);
}
