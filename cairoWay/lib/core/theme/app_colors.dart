import 'package:flutter/material.dart';

/// CairoWay/RouteMind Premium Brand Identity — Emerald Green Navigation System
/// Egypt's flagship AI-powered mobility platform with sophisticated emerald-gold palette.
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════
  // LIGHT MODE — Emerald Glass Design System
  // ═══════════════════════════════════════════════════════════════════════

  /// Map background base — soft neutral gray
  static const Color lightBackground = Color(0xFFF4F7F6);

  /// Primary accent — emerald green for buttons, icons, active states
  static const Color lightPrimary = Color(0xFF059669);

  /// Darker emerald for pressed states
  static const Color lightPrimaryDark = Color(0xFF047857);

  /// Soft green surface for primary containers
  static const Color lightPrimaryContainer = Color(0xFFD1FAE5);

  /// Premium warm gold — AI recommendations, smart features
  static const Color lightAccent = Color(0xFFD9A441);

  /// Pure white surface for glass panels
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Elevated white surface
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);

  /// Primary dark text
  static const Color lightOnSurface = Color(0xFF1F2937);

  /// Secondary muted text
  static const Color lightOnSurfaceMuted = Color(0xFF6B7280);

  /// Neutral light border
  static const Color lightDivider = Color(0xFFE5E7EB);

  // ═══════════════════════════════════════════════════════════════════════
  // DARK MODE — Emerald Glass Design System
  // ═══════════════════════════════════════════════════════════════════════

  /// Map background base — deep charcoal
  static const Color darkBackground = Color(0xFF121517);

  /// Dark charcoal surface — slightly lighter than background
  static const Color darkSurface = Color(0xFF1A1F24);

  /// Elevated card surface — used for cards layered above background
  static const Color darkSurfaceElevated = Color(0xFF0F172A);

  /// Primary accent — vibrant emerald green
  static const Color darkPrimary = Color(0xFF00D26A);

  /// Secondary accent — deeper emerald
  static const Color darkSecondary = Color(0xFF008F48);

  /// Deep green container
  static const Color darkPrimaryContainer = Color(0xFF0B2018);

  /// Premium muted gold accent
  static const Color darkAccent = Color(0xFFD9A441);

  /// Light text on dark surfaces — pure white
  static const Color darkOnSurface = Color(0xFFFFFFFF);

  /// Muted text on dark — cool gray
  static const Color darkOnSurfaceMuted = Color(0xFFA0AAB2);

  /// Subtle dark border
  static const Color darkDivider = Color(0xFF1E2922);

  // ═══════════════════════════════════════════════════════════════════════
  // TRAFFIC SEMANTIC COLORS — Universal System
  // ═══════════════════════════════════════════════════════════════════════
  
  static const Color trafficFree = Color(0xFF00D26A);        // Emerald green
  static const Color trafficLight = Color(0xFF84CC16);       // Fresh lime
  static const Color trafficModerate = Color(0xFFFF9800);    // Amber
  static const Color trafficHeavy = Color(0xFFF44336);       // Red
  static const Color trafficGridlock = Color(0xFFB71C1C);    // Dark red

  // ═══════════════════════════════════════════════════════════════════════
  // STATUS & ALERT COLORS
  // ═══════════════════════════════════════════════════════════════════════
  
  static const Color success = Color(0xFF00D26A);            // Emerald green
  static const Color warning = Color(0xFFD9A441);            // Gold
  static const Color error = Color(0xFFF44336);              // Modern red
  static const Color info = Color(0xFF00D26A);               // Emerald green

  // ═══════════════════════════════════════════════════════════════════════
  // PREMIUM GRADIENTS — Emerald Green System
  // ═══════════════════════════════════════════════════════════════════════
  
  /// Primary emerald gradient for buttons, CTAs, active states
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x9900D26A), Color(0x99008F48)],
  );
  
  /// AI/Premium gradient with gold accent
  static const LinearGradient aiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x99D9A441), Color(0x99B8883A)],
  );
  
  /// Hybrid emerald-gold gradient for premium AI features
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x9900D26A), Color(0x99D9A441)],
  );
  
  /// Dark mode hero gradient — deep emerald tones
  static const LinearGradient darkHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x99123D35), Color(0x990B2E26)],
  );
  
  /// Soft green accent gradient for highlights
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x9900D26A), Color(0x9910B981)],
  );

  // ═══════════════════════════════════════════════════════════════════════
  // EMERALD GLASS DESIGN SYSTEM — Exact glassmorphism recipe from reference
  // ═══════════════════════════════════════════════════════════════════════

  /// Glass panel glow color — subtle emerald tint
  static Color glassGlow(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF00D26A).withValues(alpha: 0.05)
          : Colors.transparent;

  /// Primary glass gradient — matches reference image exactly
  /// Dark: Deep slate gradient with translucency
  /// Light: Frosted white gradient with translucency
  static LinearGradient glassGradient(Brightness brightness) =>
      brightness == Brightness.dark
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromRGBO(30, 41, 59, 0.4),  // rgba(30, 41, 59, 0.4)
                Color.fromRGBO(15, 23, 42, 0.6),  // rgba(15, 23, 42, 0.6)
              ],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromRGBO(255, 255, 255, 0.7),  // rgba(255, 255, 255, 0.7)
                Color.fromRGBO(255, 255, 255, 0.4),  // rgba(255, 255, 255, 0.4)
              ],
            );

  /// Glass border — subtle definition with top highlight
  static Color glassBorder(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.6);

  /// Glass border top highlight — brighter top edge for depth
  static Color glassBorderTop(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.8);

  /// Accent glass border — emerald for selected/highlighted states
  static Color glassBorderAccent(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF00D26A).withValues(alpha: 0.60)
          : const Color(0xFF059669).withValues(alpha: 0.50);

  /// Premium layered shadow system with emerald glow
  static List<BoxShadow> glassShadow(Brightness brightness) => [
        BoxShadow(
          color: brightness == Brightness.dark
              ? Colors.black38
              : const Color(0x12262758),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
        if (brightness == Brightness.dark)
          BoxShadow(
            color: const Color(0xFF00D26A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: Offset.zero,
          ),
      ];

  /// Specular inner edge highlight — simulates glass refractive edge
  static BoxBorder glassInnerHighlight(Brightness brightness) =>
      brightness == Brightness.dark
          ? Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            )
          : Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1,
              ),
            );

  /// Light glass fill for nested cards, chips, and input backgrounds
  static Color glassFillLight(Brightness brightness) {
    return brightness == Brightness.dark
        ? const Color.fromRGBO(30, 41, 59, 0.4) // Dark mode glass
        : const Color.fromRGBO(255, 255, 255, 0.7); // Light mode glass
  }
}
