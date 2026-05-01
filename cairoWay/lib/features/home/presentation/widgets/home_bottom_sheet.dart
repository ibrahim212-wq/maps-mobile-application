import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../shared/models/place.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/premium_button.dart';

/// Persistent draggable bottom sheet sitting above the bottom navigation.
///
/// Peek state shows greeting + AI status + primary action. Expanding reveals
/// recent destinations and saved places without overlapping the map's
/// floating controls (it never grows beyond ~50%).
class HomeBottomSheet extends ConsumerWidget {
  const HomeBottomSheet({super.key, required this.bottomNavHeight});

  final double bottomNavHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;

    // Reserve space for: bottom-nav + safe-area inset.
    final reservedBottom = bottomNavHeight + mq.padding.bottom;
    final minSize = 0.28;
    final initialSize = 0.28;
    final maxSize = 0.85;

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      snap: true,
      snapSizes: [minSize, maxSize],
      builder: (ctx, scrollCtrl) {
        return GlassContainer(
          borderRadius: 28,
          padding: EdgeInsets.zero,
          child: ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(24, 16, 24, reservedBottom + 24),
            physics: const ClampingScrollPhysics(),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color:
                        scheme.onSurfaceVariant.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const _GreetingHeader(),
              const SizedBox(height: 20),
              const _PrimaryActionRow(),
              const SizedBox(height: 20),
              const _BestTimeChip(),
              const SizedBox(height: 28),
              const _RecentsSection(),
            ],
          ),
        ).animate().fadeIn(delay: 250.ms, duration: 400.ms);
      },
    );
  }
}

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final storage = ref.watch(storageServiceProvider);
    final home = storage.savedByLabel('home');
    final work = storage.savedByLabel('work');
    final hasCommute = home != null && work != null;
    final time = DateFormat.jm().format(DateTime.now());

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_greeting(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 2),
              Text(
                hasCommute
                    ? 'AI service initializing — predictions soon'
                    : 'Save your places to unlock smart commutes',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(time,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                )),
      ],
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _PrimaryActionRow extends ConsumerWidget {
  const _PrimaryActionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final home = storage.savedByLabel('home');
    final work = storage.savedByLabel('work');
    final hasWork = work != null;

    return Row(
      children: [
        Expanded(
          child: PremiumButton(
            label: hasWork ? 'Navigate to work' : 'Set up commute',
            icon: hasWork
                ? Icons.navigation_rounded
                : Icons.add_location_alt_rounded,
            onPressed: () {
              if (hasWork) {
                context.push(AppRoutes.routeOptions, extra: {
                  'destination': work.place,
                });
              } else {
                context.push(AppRoutes.onboarding);
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        PremiumButton(
          label: 'Explore',
          icon: Icons.travel_explore_rounded,
          expand: false,
          variant: PremiumButtonVariant.ghost,
          onPressed: () => context.push(AppRoutes.search),
        ),
        if (home != null) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Navigate home',
            onPressed: () => context.push(AppRoutes.routeOptions,
                extra: {'destination': home.place}),
            icon: const Icon(Icons.home_rounded),
          ),
        ],
      ],
    );
  }
}

class _RecentsSection extends ConsumerWidget {
  const _RecentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final storage = ref.watch(storageServiceProvider);
    final recents = storage.recents();
    final saved = storage.savedPlaces();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (saved.isNotEmpty) ...[
          _SectionLabel('Saved places'),
          for (final s in saved.take(4))
            _PlaceListTile(
              icon: _iconForLabel(s.label),
              title: _capitalize(s.label),
              subtitle: s.place.name,
              onTap: () => context.push(AppRoutes.routeOptions,
                  extra: {'destination': s.place}),
            ),
          const SizedBox(height: 8),
        ],
        _SectionLabel(recents.isEmpty
            ? 'Tip'
            : 'Recent destinations'),
        if (recents.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              'Search a place to see it here next time.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
          )
        else
          for (final r in recents.take(8))
            _PlaceListTile(
              icon: Icons.history_rounded,
              title: r.name,
              subtitle: r.address,
              onTap: () => context.push(AppRoutes.routeOptions,
                  extra: {'destination': r}),
            ),
      ],
    );
  }

  IconData _iconForLabel(String label) => switch (label) {
        'home' => Icons.home_rounded,
        'work' => Icons.business_center_rounded,
        _ => Icons.bookmark_rounded,
      };

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Premium glass chip surfacing the "Plan best departure time" entry.
///
/// Sits below the primary action row so Navigate / Explore / Home stay
/// visually dominant. Tapping it routes to the Best-Time screen using the
/// user's saved work or home place as the destination, with the current
/// GPS location (or Cairo fallback) as origin.
class _BestTimeChip extends ConsumerWidget {
  const _BestTimeChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final storage = ref.watch(storageServiceProvider);
    final destination =
        storage.savedByLabel('work')?.place ?? storage.savedByLabel('home')?.place;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 18,
      blur: 36,
      tint: AppColors.glassFillLight(brightness),
      onTap: () async {
        if (destination == null) {
          context.push(AppRoutes.search);
          return;
        }
        final loc =
            await ref.read(locationServiceProvider).currentLocation();
        if (!context.mounted) return;
        final origin = loc != null
            ? Place(
                id: 'current_location',
                name: 'Current location',
                lat: loc.lat,
                lng: loc.lng,
              )
            : const Place(
                id: 'cairo_fallback',
                name: 'Current location',
                lat: AppConstants.defaultLat,
                lng: AppConstants.defaultLng,
              );
        context.push(AppRoutes.bestTime, extra: {
          'origin': origin,
          'destination': destination,
        });
      },
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  destination != null
                      ? 'Plan best time to go'
                      : 'Arrive on time',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  destination != null
                      ? 'Arrive on time, every time'
                      : 'Pick a destination to get started',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _PlaceListTile extends StatelessWidget {
  const _PlaceListTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

