import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_container.dart';

/// Frosted glass search-bar pinned to the top of the map.
class MapSearchBar extends StatelessWidget {
  const MapSearchBar({super.key, this.onProfileTap});
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: GlassContainer.pill(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(AppRoutes.search);
          },
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.search_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Where to?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: onProfileTap,
                  icon: Icon(Icons.tune_rounded,
                      color: scheme.onSurfaceVariant, size: 22),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.15, end: 0),
      ),
    );
  }
}
