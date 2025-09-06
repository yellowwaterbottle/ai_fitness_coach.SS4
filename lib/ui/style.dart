import 'package:flutter/material.dart';

class AppStyle {
  // Dark navy palette
  static const Color bg = Color(0xFF0E1220);
  static const Color bgTop = Color(0xFF0E1220);
  static const Color bgBottom = Color(0xFF171C2D);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB7C2D0);
  static const Color chipBorder = Color(0xFF2C3752);
  static const Color chipFill = Color(0x1A90EE90); // faint green fill

  // Capture gradient (purplish to teal)
  static const Gradient captureGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7C3AED), // purple
      Color(0xFF5EEAD4), // teal
    ],
  );

  // CTA gradient for buttons
  static const LinearGradient ctaGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF5EEAD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient pageBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );

  static TextStyle get title =>
      const TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700, height: 1.25);

  static TextStyle get caption =>
      const TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500);

  static TextStyle get hero =>
      const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.15);

  static TextStyle get sub =>
      const TextStyle(color: Color(0xFFB7C2D0), fontSize: 14, fontWeight: FontWeight.w500);

  static BoxDecoration get glassCard => BoxDecoration(
    color: const Color(0x141A2236),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0x1FFFFFFF)),
  );

  static List<BoxShadow> get glow => [
    BoxShadow(color: const Color(0x805EEAD4), blurRadius: 24, spreadRadius: 2),
    BoxShadow(color: const Color(0x407C3AED), blurRadius: 16, spreadRadius: 1),
  ];

  static List<BoxShadow> get softGlow => [
    const BoxShadow(color: Color(0x405EEAD4), blurRadius: 32, spreadRadius: 2),
    const BoxShadow(color: Color(0x407C3AED), blurRadius: 16, spreadRadius: 1),
  ];
}
