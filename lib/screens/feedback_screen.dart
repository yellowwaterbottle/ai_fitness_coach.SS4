import 'package:flutter/material.dart';
import '../ui/style.dart';
import '../ui/gradient_ring.dart';
import '../models/score_response.dart';
import '../models/score_labels.dart';

class FeedbackScreen extends StatelessWidget {
  static const routeName = '/feedback';
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ScoreResponse score =
        ModalRoute.of(context)!.settings.arguments as ScoreResponse;

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
                  const SizedBox(height: 14),
                  _MainScoreBreakdownCard(resp: score),
                  const SizedBox(height: 16),
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

class _MainScoreBreakdownCard extends StatelessWidget {
  final ScoreResponse resp;
  const _MainScoreBreakdownCard({required this.resp});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0x141A2236),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeaderRow(title: "Form", score: resp.form),
              const SizedBox(height: 10),
              _SubSectionBarsForm(items: resp.formSubs, overallFallback: resp.form),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0x141A2236),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeaderRow(title: "Intensity", score: resp.intensity),
              const SizedBox(height: 10),
              _SubSectionBarsIntensity(items: resp.intensitySubs, overallFallback: resp.intensity),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final int score;
  const _SectionHeaderRow({required this.title, required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const Spacer(),
        _GradientScoreChip(value: score),
      ],
    );
  }
}

class _GradientScoreChip extends StatelessWidget {
  final int value;
  const _GradientScoreChip({required this.value});

  @override
  Widget build(BuildContext context) {
    const double size = 44;
    const double ring = 4;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppStyle.scoreGradient, // same as Holistic
        boxShadow: AppStyle.softGlow,
      ),
      child: Center(
        child: Container(
          width: size - ring*2,
          height: size - ring*2,
          decoration: BoxDecoration(
            color: const Color(0xFF0E1220), // inner fill matches page bg for contrast
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            "$value",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              height: 1.0,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubSectionBarsForm extends StatelessWidget {
  final List<CategoryScore<SubFormKey>> items;
  final int overallFallback;
  const _SubSectionBarsForm({required this.items, required this.overallFallback});

  @override
  Widget build(BuildContext context) {
    final list = items.isEmpty
        ? SubFormKey.values.map((k) => CategoryScore(key: k, score: overallFallback)).toList()
        : items;

    return Column(
      children: list.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _MetricBar(label: kFormLabels[e.key]!, value: e.score / 100.0),
      )).toList(),
    );
  }
}

class _SubSectionBarsIntensity extends StatelessWidget {
  final List<CategoryScore<SubIntensityKey>> items;
  final int overallFallback;
  const _SubSectionBarsIntensity({required this.items, required this.overallFallback});

  @override
  Widget build(BuildContext context) {
    final list = items.isEmpty
        ? SubIntensityKey.values.map((k) => CategoryScore(key: k, score: overallFallback)).toList()
        : items;

    return Column(
      children: list.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _MetricBar(label: kIntensityLabels[e.key]!, value: e.score / 100.0),
      )).toList(),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final double value; // 0..1
  const _MetricBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, overflow: TextOverflow.ellipsis, maxLines: 1,
          style: const TextStyle(color: Color(0xFFB7C2D0), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            return Stack(
              children: [
                // Track
                Container(
                  height: 10,
                  width: w,
                  decoration: BoxDecoration(
                    color: const Color(0x1FFFFFFF),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                // Fill with score gradient
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  height: 10,
                  width: w * v,
                  decoration: BoxDecoration(
                    gradient: AppStyle.scoreGradient, // use shared gradient
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: const [
                      BoxShadow(color: Color(0x405EEAD4), blurRadius: 10, spreadRadius: 0), // teal-ish
                      BoxShadow(color: Color(0x407C3AED), blurRadius: 12, spreadRadius: 0), // purple-ish
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}