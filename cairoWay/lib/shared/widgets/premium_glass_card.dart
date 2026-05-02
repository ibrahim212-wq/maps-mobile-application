import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';

class PremiumGlassCard extends StatelessWidget {
  const PremiumGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.isStrong = false,
    this.onTap,
    this.showHighlight = true,
    this.showGlow = false,
    this.glowColor,
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool isStrong;
  final VoidCallback? onTap;
  final bool showHighlight;
  final bool showGlow;
  final Color? glowColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    final fill = backgroundColor ??
        (isDark
            ? (isStrong
                ? AppColors.darkGlassFillStrong
                : AppColors.darkGlassFill)
            : (isStrong
                ? AppColors.lightGlassFillStrong
                : AppColors.lightGlassFill));

    final stroke = borderColor ??
        (isDark
            ? (isStrong
                ? AppColors.darkGlassStroke
                : AppColors.darkGlassStrokeSoft)
            : AppColors.lightGlassStrokeSecondary);

    final blurSigma = isDark
        ? (isStrong ? 20.0 : 14.0)
        : (isStrong ? 16.0 : 10.0);

    final shadows = <BoxShadow>[
      if (showGlow)
        BoxShadow(
          color: (glowColor ?? AppColors.primaryGreen)
              .withValues(alpha: isDark ? 0.24 : 0.16),
          blurRadius: isStrong ? 34 : 24,
          spreadRadius: -4,
          offset: const Offset(0, 10),
        ),
      ...(isDark
          ? AppShadows.darkGlass(isStrong ? 1.0 : 0.65)
          : AppShadows.lightGlass(isStrong ? 1.0 : 0.75)),
    ];

    Widget glass = Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: Border.all(color: stroke, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.08),
                        fill,
                        Colors.black.withValues(alpha: 0.08),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.95),
                        fill,
                        Colors.white.withValues(alpha: 0.54),
                      ],
              ),
            ),
            child: Stack(
              children: [
                if (showHighlight)
                  Positioned(
                    left: 1,
                    right: 1,
                    top: 1,
                    child: Container(
                      height: 1.2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(borderRadius),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(
                              alpha: isDark ? 0.28 : 0.95,
                            ),
                            Colors.white.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      glass = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: glass,
        ),
      );
    }

    return glass;
  }
}