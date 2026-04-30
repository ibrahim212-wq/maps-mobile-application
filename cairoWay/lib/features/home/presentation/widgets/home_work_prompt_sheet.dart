import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../providers/home_prompt_provider.dart';

/// Premium Material 3 modal bottom-sheet that invites the user to set up
/// Home & Work. Dismissible via X button, "Maybe later", or by selecting
/// "Set up now" (which navigates to onboarding).
///
/// Tapping any of these permanently sets
/// [AppConstants.prefHomeWorkPromptDismissed] to true so the sheet never
/// appears again on this device.
class HomeWorkPromptSheet extends ConsumerWidget {
  const HomeWorkPromptSheet({super.key});

  /// Convenience helper to show the sheet with the correct theming.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const HomeWorkPromptSheet(),
    );
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    await ref.read(homeWorkPromptDismissedProvider.notifier).dismiss();
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _setUpNow(BuildContext context, WidgetRef ref) async {
    await ref.read(homeWorkPromptDismissedProvider.notifier).dismiss();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    await context.push(AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          borderRadius: 24,
          tint: dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.78),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Header row: gradient circle icon + close button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.32),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.home_work_rounded,
                        color: Colors.white, size: 26),
                  )
                      .animate()
                      .scale(
                          duration: 350.ms,
                          curve: Curves.easeOutBack,
                          begin: const Offset(0.7, 0.7))
                      .then()
                      .shimmer(duration: 1600.ms, color: Colors.white24),
                  const Spacer(),
                  // Close (X) button
                  IconButton(
                    tooltip: 'Dismiss',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _dismiss(context, ref);
                    },
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      foregroundColor: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Set up Home & Work',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Save your most-visited places to unlock faster routing and '
                'smarter commute predictions. You can do this anytime from '
                'your profile.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: PremiumButton(
                      label: 'Set up now',
                      icon: Icons.tune_rounded,
                      onPressed: () => _setUpNow(context, ref),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => _dismiss(context, ref),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 18),
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                    child: const Text('Maybe later'),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.15, end: 0),
      ),
    );
  }
}
