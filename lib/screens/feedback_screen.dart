import 'package:flutter/material.dart';
import '../ui/style.dart';
import '../ui/gradient_ring.dart';
import '../ui/breakdown_list.dart';
import '../services/breakdown_mapper.dart';
import '../models/score_response.dart';
import '../models/breakdown.dart';

class FeedbackScreen extends StatelessWidget {
  static const routeName = '/feedback';
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ScoreResponse score =
        ModalRoute.of(context)!.settings.arguments as ScoreResponse;
    final formItems = BreakdownMapper.formFrom(score);
    final intensityItems = BreakdownMapper.intensityFrom(score);

    return Container(
      decoration: const BoxDecoration(gradient: AppStyle.pageBg),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Scorecard', style: TextStyle(color: Colors.white)),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              children: [
                if (score.insufficient) ...[
                  // Show insufficient analysis message
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0x141A2236),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x1FFFFFFF)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Insufficient video for full analysis',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text('Tips for better analysis:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text('• Good lighting', style: TextStyle(color: Colors.white70)),
                        const Text('• Full body and bar in frame', style: TextStyle(color: Colors.white70)),
                        const Text('• Stable phone position', style: TextStyle(color: Colors.white70)),
                        const Text('• Clear view of form', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ] else ...[
                  // --- Holistic at top ---
                  GradientRing(
                    size: 180,
                    stroke: 12,
                    percent: score.holisticPercent,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${score.holistic}", style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        const Text("Holistic", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // --- Two columns: Form (left) | Intensity (right) ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FORM
                      Expanded(
                        child: _ScoreColumn(
                          title: "Form",
                          percent: score.formPercent,
                          value: score.form,
                          items: formItems,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // INTENSITY
                      Expanded(
                        child: _ScoreColumn(
                          title: "Intensity",
                          percent: score.intensityPercent,
                          value: score.intensity,
                          items: intensityItems,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30),
                      ),
                      child: const Text("Done"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Rescan"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _ScoreColumn extends StatelessWidget {
  final String title;
  final double percent;
  final int value;
  final List<BreakdownItem> items;
  const _ScoreColumn({
    required this.title,
    required this.percent,
    required this.value,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0x111A2236),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x12FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with small ring + title + value
          Row(
            children: [
              GradientRing(
                size: 44, stroke: 5, percent: percent,
                center: Text("$value", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          BreakdownList(items: items),
        ],
      ),
    );
  }
}