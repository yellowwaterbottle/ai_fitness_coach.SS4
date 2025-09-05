import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'style.dart';

class GradientRing extends StatelessWidget {
  final double size;             // total square size
  final double stroke;           // ring thickness
  final double percent;          // 0..1
  final Duration duration;       // anim duration
  final Widget? center;          // widget inside ring
  final Gradient? gradient;      // ring gradient (defaults to AppStyle.captureGradient)
  final Color trackColor;        // background ring color
  final bool startAtTop;         // start angle
  const GradientRing({
    super.key,
    required this.percent,
    this.size = 164,
    this.stroke = 10,
    this.duration = const Duration(milliseconds: 900),
    this.center,
    this.gradient,
    this.trackColor = const Color(0x22FFFFFF),
    this.startAtTop = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: p),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return CustomPaint(
          painter: _RingPainter(
            progress: value,
            stroke: stroke,
            gradient: (gradient ?? AppStyle.captureGradient) as LinearGradient,
            track: trackColor,
            startAngle: startAtTop ? -math.pi/2 : 0,
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(child: center),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double stroke;
  final LinearGradient gradient;
  final Color track;
  final double startAngle;
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.gradient,
    required this.track,
    required this.startAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = (size.shortestSide - stroke) / 2;
    final center = Offset(size.width/2, size.height/2);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0, 2*math.pi, false, trackPaint,
    );

    if (progress > 0) {
      final sweep = 2*math.pi * progress;
      final shader = gradient.createShader(rect);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.stroke != stroke || old.gradient != gradient;
}
