import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PremiumBottomSheet extends StatelessWidget {
  const PremiumBottomSheet({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fill = backgroundColor ??
        (isDark
            ? AppColors.darkGlassFillStrong
            : AppColors.lightGlassFillStrong);

    final stroke =
        isDark ? AppColors.darkGlassStroke : AppColors.lightGlassStrokeSecondary;

    final radius = const BorderRadius.only(
      topLeft: Radius.circular(34),
      topRight: Radius.circular(34),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.42)
                : const Color(0x1F0F232D),
            blurRadius: 42,
            spreadRadius: -8,
            offset: const Offset(0, -14),
          ),
          if (isDark)
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.10),
              blurRadius: 32,
              spreadRadius: -10,
              offset: const Offset(0, -8),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isDark ? 20 : 16,
            sigmaY: isDark ? 20 : 16,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: isDark
    ? Border(top: BorderSide(color: stroke, width: 1.2))
    : Border.all(color: const Color(0xFF00A854), width: 1.5),
              
                     
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 52,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.30)
                        : Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: padding != null
                      ? Padding(padding: padding!, child: child)
                      : child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}