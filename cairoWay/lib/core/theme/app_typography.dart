import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium typography for RouteMind. Plus Jakarta Sans (LTR) + Tajawal (Arabic).
class AppTypography {
  AppTypography._();

  static TextTheme buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.whiteMountainView
        : Typography.blackMountainView;
    return GoogleFonts.plusJakartaSansTextTheme(base).copyWith(
      displayLarge: _w(base.displayLarge, 36, FontWeight.w700, -0.5),
      displayMedium: _w(base.displayMedium, 30, FontWeight.w700, -0.4),
      displaySmall: _w(base.displaySmall, 26, FontWeight.w700, -0.3),
      headlineLarge: _w(base.headlineLarge, 24, FontWeight.w700, -0.2),
      headlineMedium: _w(base.headlineMedium, 22, FontWeight.w600, -0.2),
      headlineSmall: _w(base.headlineSmall, 20, FontWeight.w600, -0.1),
      titleLarge: _w(base.titleLarge, 18, FontWeight.w600, -0.1),
      titleMedium: _w(base.titleMedium, 16, FontWeight.w600, 0),
      titleSmall: _w(base.titleSmall, 14, FontWeight.w600, 0.1),
      bodyLarge: _w(base.bodyLarge, 16, FontWeight.w500, 0),
      bodyMedium: _w(base.bodyMedium, 14, FontWeight.w500, 0.1),
      bodySmall: _w(base.bodySmall, 12, FontWeight.w500, 0.2),
      labelLarge: _w(base.labelLarge, 14, FontWeight.w600, 0.2),
      labelMedium: _w(base.labelMedium, 12, FontWeight.w600, 0.3),
      labelSmall: _w(base.labelSmall, 11, FontWeight.w600, 0.4),
    ).apply(fontFamily: GoogleFonts.plusJakartaSans().fontFamily);
  }

  static TextStyle? _w(TextStyle? s, double size, FontWeight w, double sp) {
    return GoogleFonts.plusJakartaSans(
      textStyle: s,
      fontSize: size,
      fontWeight: w,
      letterSpacing: sp,
      height: 1.25,
    );
  }

  static TextStyle arabic(TextStyle? base, {double? size, FontWeight? weight}) {
    return GoogleFonts.tajawal(
      textStyle: base,
      fontSize: size,
      fontWeight: weight,
      height: 1.4,
    );
  }
}
