import 'package:flutter/foundation.dart';

enum BreakdownPolarity { penalty, credit, neutral }

@immutable
class BreakdownItem {
  final String title;      // short label
  final String? note;      // optional detail
  final int points;        // +/- contribution rounded
  final BreakdownPolarity polarity;
  final String? metricKey; // optional schema key
  
  const BreakdownItem({
    required this.title,
    required this.points,
    required this.polarity,
    this.note,
    this.metricKey,
  });
}
