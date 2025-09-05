import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../ui/style.dart';

class AnimatedGradientSquare extends StatefulWidget {
  final double size;          // outer box size
  final double strokeWidth;   // outline thickness
  final Duration period;      // full rotation duration
  const AnimatedGradientSquare({
    super.key,
    this.size = 210,
    this.strokeWidth = 2.5,
    this.period = const Duration(seconds: 6),
  });
  @override
  State<AnimatedGradientSquare> createState() => _AnimatedGradientSquareState();
}

class _AnimatedGradientSquareState extends State<AnimatedGradientSquare> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period)..repeat();
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size, height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          // Start from ~45° to match the mock, then spin
          final angle = (math.pi / 4) + (_c.value * 2 * math.pi);
          return Transform.rotate(
            angle: angle,
            child: CustomPaint(
              painter: _GradientSquarePainter(strokeWidth: widget.strokeWidth),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _GradientSquarePainter extends CustomPainter {
  final double strokeWidth;
  _GradientSquarePainter({required this.strokeWidth});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Create a gradient shader that follows the rect
   final gradient = AppStyle.captureGradient as LinearGradient;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);

    // Inset to keep stroke fully visible
    final inset = strokeWidth / 2 + 1;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      const Radius.circular(10),
    );
    // Draw the outline
    final path = Path()..addRRect(r);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant _GradientSquarePainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth;
}
