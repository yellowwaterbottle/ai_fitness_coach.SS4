import 'package:flutter/material.dart';
import '../models/score_response.dart';
import '../models/failure_copy.dart';
import '../ui/style.dart';

class ScorecardFailedScreen extends StatelessWidget {
  final FailureInfo failure;
  const ScorecardFailedScreen({super.key, required this.failure});

  static String route = '/scorecard_failed';

  @override
  Widget build(BuildContext context) {
    final isNoSet = failure.status == AnalysisStatus.no_set;
    final title = isNoSet ? "Training set not detected" : "Conditions insufficient for proper analysis";

    return Scaffold(
      backgroundColor: AppStyle.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text("Scorecard", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            _WarningCard(
              title: title,
              reasons: isNoSet ? const [] : failure.reasons.map((r) => kCanonicalFailureCopy[r]!).toList(),
              showTipList: !isNoSet,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _GhostBtn(
                    label: "Done",
                    onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _PrimaryBtn(
                    label: "Rescan",
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final String title;
  final List<String> reasons;
  final bool showTipList;
  const _WarningCard({required this.title, required this.reasons, required this.showTipList});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: const Color(0x141A2236),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFF9A825), size: 36),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (reasons.isNotEmpty)
            Column(
              children: [
                const Text("Detected issues:", style: TextStyle(color: Color(0xFFB7C2D0), fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...reasons.map((r) => _ReasonRow(text: r)),
                const SizedBox(height: 8),
              ],
            ),
          if (showTipList) ...[
            const SizedBox(height: 4),
            const Text("Tips for better analysis:", style: TextStyle(color: Color(0xFFB7C2D0), fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const _TipBullet(text: "Good lighting"),
            const _TipBullet(text: "Full body and bar in frame"),
            const _TipBullet(text: "Stable phone position"),
            const _TipBullet(text: "Clear view of form"),
          ],
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final String text;
  const _ReasonRow({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.cancel_rounded, color: Color(0xFFFF6E6E), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
    );
  }
}

class _TipBullet extends StatelessWidget {
  final String text;
  const _TipBullet({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF7CF29A), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppStyle.ctaGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppStyle.softGlow,
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _GhostBtn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _GhostBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
