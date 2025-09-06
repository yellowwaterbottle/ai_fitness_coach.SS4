import 'score_response.dart';

const Map<FailReason, String> kCanonicalFailureCopy = {
  FailReason.poor_lighting: "Video failed due to poor lighting.",
  FailReason.subject_out_of_frame: "Lifter and/or barbell not fully visible in frame.",
  FailReason.camera_motion: "Camera moved too much during the set.",
  FailReason.too_short_clip: "Clip is too short to analyze a set.",
  FailReason.blurry_frames: "Video is too blurry for reliable analysis.",
  FailReason.wrong_orientation: "Video orientation is not portrait.",
  FailReason.occlusions: "Lifter or barbell is blocked from view.",
  FailReason.bar_not_visible: "Barbell is not visible enough to analyze bar path.",
  FailReason.multiple_people: "Multiple people in frame caused ambiguity.",
  FailReason.file_corrupt: "Video file couldn't be decoded."
};
