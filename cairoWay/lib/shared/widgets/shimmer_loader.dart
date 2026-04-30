import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loader, themed for light/dark.
class ShimmerLoader extends StatelessWidget {
  const ShimmerLoader({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 8,
    this.backgroundColor,
  });
  final double? width;
  final double height;
  final double borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF1B2B25) : const Color(0xFFD1FAE5),
      highlightColor: dark ? const Color(0xFF21453B) : const Color(0xFFDFF7EC),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          const ShimmerLoader(width: 44, height: 44, borderRadius: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerLoader(width: 180, height: 14),
                SizedBox(height: 8),
                ShimmerLoader(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
