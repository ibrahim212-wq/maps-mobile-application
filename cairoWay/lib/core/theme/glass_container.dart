import 'package:flutter/material.dart';

/// Emerald Glass container using pure semi-transparency.
///
/// Uses low alpha colors to let the map show through directly. No BackdropFilter.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding = const EdgeInsets.all(20),
    this.width,
    this.height,
    this.onTap,
  });

  /// Pill-shaped variant for search bars and chips.
  const GlassContainer.pill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.width,
    this.height,
    this.onTap,
  }) : borderRadius = 9999;

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    // Determine variant heuristics
    final bool isPill = borderRadius >= 9999;
    final bool isSmallButton = (width != null && height != null &&
        width == 48 && height == 48 && borderRadius.round() == 16);

    // Resolve decoration per new spec
    Color backgroundColor;
    Color borderColor;
    double borderWidth;
    List<BoxShadow>? shadows;

    if (isPill) {
      if (isDark) {
        backgroundColor = const Color(0x4D0A1F14);
        borderColor = const Color(0x4D00D26A);
        borderWidth = 1.0;
        shadows = null;
      } else {
        backgroundColor = const Color(0xB3FFFFFF);
        borderColor = const Color(0x1A059669);
        borderWidth = 1.0;
        shadows = const [
          BoxShadow(color: Color(0x2600D26A), blurRadius: 20, spreadRadius: 2),
        ];
      }
    } else if (isSmallButton) {
      if (isDark) {
        backgroundColor = const Color(0x66071510);
        borderColor = const Color(0x4400D26A);
        borderWidth = 1.0;
        shadows = null;
      } else {
        backgroundColor = const Color(0xB3FFFFFF);
        borderColor = const Color(0x1A059669);
        borderWidth = 1.0;
        shadows = null;
      }
    } else {
      if (isDark) {
        backgroundColor = const Color(0x4D0A1F14);
        borderColor = const Color(0x3300D26A);
        borderWidth = 1.0;
        shadows = const [
          BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 4)),
        ];
      } else {
        backgroundColor = const Color(0x99FFFFFF);
        borderColor = const Color(0x1A059669);
        borderWidth = 1.0;
        shadows = const [
          BoxShadow(color: Color(0x1A059669), blurRadius: 12),
        ];
      }
    }

    final Widget simulated = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: simulated,
        ),
      );
    }

    return simulated;
  }
}
