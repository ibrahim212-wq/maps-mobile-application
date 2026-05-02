import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static List<BoxShadow> darkGlass(double intensity) {
    return [
      BoxShadow(
        color: const Color(0x59000000), // rgba(0,0,0,0.35)
        blurRadius: 24.0 + (12.0 * intensity),
        offset: Offset(0, 10.0 + (8.0 * intensity)),
      ),
    ];
  }

  static List<BoxShadow> lightGlass(double intensity) {
    return [
      BoxShadow(
        color: const Color(0x1F0F232D), // rgba(15,35,45,0.12)
        blurRadius: 28.0 + (14.0 * intensity),
        offset: Offset(0, 12.0 + (8.0 * intensity)),
      ),
    ];
  }

  static List<BoxShadow> primaryGlow(double intensity) {
    return [
      BoxShadow(
        color: const Color(0xFF00C875).withValues(alpha: 0.20 + (0.10 * intensity)),
        blurRadius: 28.0 + (12.0 * intensity),
        offset: const Offset(0, 8),
      ),
    ];
  }
}
