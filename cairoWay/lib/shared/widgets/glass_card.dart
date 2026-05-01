import 'package:flutter/material.dart';
import '../../core/theme/glass_container.dart';

/// Emerald Glass card using pure semi-transparency.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
    this.blur = 24, // ignored, kept for compatibility
    this.tint, // ignored
    this.borderColor, // ignored
    this.boxShadow, // ignored
    this.onTap,
    this.gradient, // ignored
    this.showInnerHighlight = true, // ignored
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
    return GlassContainer(
      padding: padding,
      borderRadius: borderRadius,
      onTap: onTap,
      child: child,
    );
  }
}
