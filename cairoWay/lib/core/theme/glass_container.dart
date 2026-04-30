import 'dart:ui';

import 'package:flutter/material.dart';

/// Emerald Glass container with exact glassmorphism recipe from reference design.
///
/// Uses ClipRRect, BackdropFilter with ImageFilter.blur, and a gradient-filled
/// Container with border and shadow. Works in both light and dark modes.
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

    final Widget inner = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x661E293B),
                  Color(0x990F172A),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xB3FFFFFF),
                  Color(0x66FFFFFF),
                ],
              ),
        borderRadius: radius,
        border: Border.all(
          color: isDark
              ? const Color(0x14FFFFFF)
              : const Color(0x99FFFFFF),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black38
                : const Color(0x12262758),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    final Widget blurred = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: inner,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: blurred,
        ),
      );
    }

    return blurred;
  }
}
