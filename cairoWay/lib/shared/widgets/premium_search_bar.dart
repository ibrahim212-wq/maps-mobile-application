import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'premium_glass_card.dart';

class PremiumSearchBar extends StatelessWidget {
  const PremiumSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onTap,
    this.hintText = 'Search here',
    this.showFilter = false,
    this.onFilterTap,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final String hintText;
  final bool showFilter;
  final VoidCallback? onFilterTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PremiumGlassCard(
      height: 64,
      borderRadius: 32,
      isStrong: true,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onTap: onTap,
              autofocus: autofocus,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (showFilter) ...[
            PremiumGlassCard(
              width: 48,
              height: 48,
              borderRadius: 24,
              isStrong: false,
              onTap: onFilterTap,
              child: const Center(
                child: Icon(Icons.tune_rounded, size: 24),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
