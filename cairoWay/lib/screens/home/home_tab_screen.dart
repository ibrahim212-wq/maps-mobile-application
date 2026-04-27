import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../providers/home_map_providers.dart';
import '../../widgets/ai_smart_card.dart';
import '../navigation_screen.dart';
import 'home_map_view.dart';

/// Home tab: full-bleed map, search, traffic toggle, AI card (card sits under search area, above bottom nav).
class HomeTabScreen extends ConsumerWidget {
  const HomeTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.viewPaddingOf(context).top;
    return Column(
      children: [
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const HomeMapView(),
              Positioned(
                top: top + 8,
                left: 16,
                right: 16,
                child: _SearchPill(),
              ),
              Positioned(
                right: 12,
                bottom: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _NavigationFab(),
                    const SizedBox(height: 8),
                    const _TrafficToggleFab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        const AiSmartCard(),
      ],
    );
  }
}

class _SearchPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(28),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Search and autocomplete will open from here.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.search, color: AppColors.textSecondary.withValues(alpha: 0.9)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Where to?',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(Icons.mic_none, color: AppColors.primary.withValues(alpha: 0.85)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens custom navigation (Mapbox Directions + map) to a fixed demo point in Greater Cairo.
class _NavigationFab extends StatelessWidget {
  const _NavigationFab();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surface,
      child: IconButton(
        tooltip: 'Demo navigation',
        icon: const Icon(
          Icons.turn_right,
          color: AppColors.primary,
        ),
        onPressed: () {
          final t = dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NavigationScreen(
                mapboxAccessToken: t,
                destinationLat: 30.0886,
                destinationLng: 31.3244,
                destinationName: 'Heliopolis (demo route)',
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrafficToggleFab extends ConsumerWidget {
  const _TrafficToggleFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(trafficOverlayEnabledProvider);
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surface,
      child: IconButton(
        tooltip: on ? 'Hide traffic' : 'Show traffic',
        icon: Icon(
          on ? Icons.layers : Icons.layers_outlined,
          color: on ? AppColors.primary : AppColors.textSecondary,
        ),
        onPressed: () {
          ref.read(trafficOverlayEnabledProvider.notifier).state = !on;
        },
      ),
    );
  }
}
