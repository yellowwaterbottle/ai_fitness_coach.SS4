import 'package:flutter/material.dart';
import '../models/breakdown.dart';
import 'style.dart';

class BreakdownList extends StatelessWidget {
  final List<BreakdownItem> items;
  final int maxItems;
  const BreakdownList({super.key, required this.items, this.maxItems = 6});

  Color _colorFor(BreakdownPolarity p) {
    switch (p) {
      case BreakdownPolarity.penalty: return const Color(0xFFE26D6D); // red
      case BreakdownPolarity.credit: return const Color(0xFF6DE2B2); // green
      case BreakdownPolarity.neutral: return const Color(0xFF8BA0B7); // gray-blue
    }
  }

  IconData _iconFor(BreakdownPolarity p) {
    switch (p) {
      case BreakdownPolarity.penalty: return Icons.remove_circle_outline;
      case BreakdownPolarity.credit: return Icons.add_circle_outline;
      case BreakdownPolarity.neutral: return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = items.take(maxItems).toList();
    if (list.isEmpty) {
      return Text("No details available", style: AppStyle.caption);
    }
    return Column(
      children: list.map((e) {
        final c = _colorFor(e.polarity);
        final sign = e.points > 0 ? '+' : '';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0x141A2236),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: Row(
            children: [
              Icon(_iconFor(e.polarity), color: c, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    if (e.note != null && e.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(e.note!, style: AppStyle.caption),
                      ),
                  ],
                ),
              ),
              if (e.points != 0)
                Text(
                  "${sign}${e.points.abs()}",
                  style: TextStyle(color: c, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
