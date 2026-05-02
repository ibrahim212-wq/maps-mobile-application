import 'package:flutter/material.dart';
import 'premium_glass_card.dart';

class PremiumIconButton extends StatelessWidget {
  const PremiumIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.size = 56.0,
    this.iconSize = 24.0,
    this.tooltip,
    this.backgroundColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final double size;
  final double iconSize;
  final String? tooltip;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine icon color based on active state and theme
    Color iColor;
    if (isActive) {
      iColor = isDark ? const Color(0xFF54E7C7) : const Color(0xFF00C875);
    } else {
      iColor = isDark ? const Color(0xF0FFFFFF) : const Color(0xFF17212B);
    }

    Widget button = PremiumGlassCard(
      width: size,
      height: size,
      borderRadius: size * 0.35, // Gives a nice squircle shape (19.6 for 56)
      isStrong: true,
      showGlow: isActive,
      onTap: onTap,
      backgroundColor: backgroundColor,
      child: Center(
        child: Icon(
          icon,
          color: iColor,
          size: iconSize,
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
