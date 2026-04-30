import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Emerald Glass card with exact glassmorphism recipe from reference design.
/// Implements gradient background, backdrop blur, dual borders, and emerald glow.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
    this.blur = 24,
    this.tint,
    this.borderColor,
    this.boxShadow,
    this.onTap,
    this.gradient,
    this.showInnerHighlight = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final Color? tint;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final bool showInnerHighlight;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final radius = BorderRadius.circular(borderRadius);
    final glassGrad = gradient ?? AppColors.glassGradient(brightness);
    final border = borderColor ?? AppColors.glassBorder(brightness);
    final shadows = boxShadow ?? AppColors.glassShadow(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: shadows,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
                tileMode: TileMode.mirror,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: glassGrad,
                  borderRadius: radius,
                  border: Border.all(color: border, width: 1),
                ),
                foregroundDecoration: showInnerHighlight
                    ? BoxDecoration(
                        border: AppColors.glassInnerHighlight(brightness),
                        borderRadius: radius,
                      )
                    : null,
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
