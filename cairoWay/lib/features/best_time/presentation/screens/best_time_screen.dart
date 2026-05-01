import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../shared/models/place.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../../home/presentation/providers/map_layer_provider.dart';
import '../../../home/presentation/widgets/map_view.dart';
import '../../domain/models/best_time_request.dart';
import '../../domain/models/time_suggestion.dart';
import '../providers/best_time_provider.dart';
import '../widgets/departure_time_picker.dart';
import '../widgets/time_suggestion_card.dart';

class BestTimeScreen extends ConsumerStatefulWidget {
  const BestTimeScreen({
    super.key,
    required this.origin,
    required this.destination,
  });

  final Place origin;
  final Place destination;

  @override
  ConsumerState<BestTimeScreen> createState() => _BestTimeScreenState();
}

class _BestTimeScreenState extends ConsumerState<BestTimeScreen> {
  late DateTime _arrival;
  int _bufferMinutes = 10;
  BestTimeRequest? _activeRequest;
  DateTime? _activeDeadline;

  @override
  void initState() {
    super.initState();
    // Default deadline: an hour from now, rounded up to the next 15 min.
    final now = DateTime.now();
    final inOneHour = now.add(const Duration(hours: 1));
    final minutes = ((inOneHour.minute / 15).ceil() * 15) % 60;
    final addHour = inOneHour.minute > 45 ? 1 : 0;
    _arrival = DateTime(
      inOneHour.year,
      inOneHour.month,
      inOneHour.day,
      inOneHour.hour + addHour,
      minutes,
    );
  }

  void _runAnalysis() {
    HapticFeedback.lightImpact();
    setState(() {
      _activeDeadline = _arrival;
      _activeRequest = BestTimeRequest(
        fromLat: widget.origin.lat,
        fromLng: widget.origin.lng,
        toLat: widget.destination.lat,
        toLng: widget.destination.lng,
        arrivalTime: _arrival.subtract(Duration(minutes: _bufferMinutes)),
      );
    });
  }

  void _startNavigation() {
    context.push(AppRoutes.routeOptions, extra: {
      'origin': widget.origin,
      'destination': widget.destination,
    });
  }

  void _notifyMe(TimeSuggestion s) {
    HapticFeedback.selectionClick();
    final t = DateFormat.jm().format(s.departureTime);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("We'll remind you at $t to leave."),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final req = _activeRequest;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Map preview showing origin → destination context.
          Positioned.fill(
            child: MapView(
              brightness: brightness,
              layer: ref.watch(mapLayerProvider),
              initialLat: widget.destination.lat,
              initialLng: widget.destination.lng,
              onMapReady: (c) async {
                await c.fitBounds([
                  [widget.origin.lng, widget.origin.lat],
                  [widget.destination.lng, widget.destination.lat],
                ]);
              },
            ),
          ),
          // Light dimming so content reads on any basemap.
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scheme.surface.withValues(alpha: 0.0),
                      scheme.surface.withValues(alpha: 0.85),
                      scheme.surface,
                    ],
                    stops: const [0.0, 0.55, 0.85],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _Header(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _RoutePreview(
                        origin: widget.origin,
                        destination: widget.destination,
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 14),
                      DepartureTimePicker(
                        value: _arrival,
                        bufferMinutes: _bufferMinutes,
                        onChanged: (v) => setState(() => _arrival = v),
                        onBufferChanged: (v) =>
                            setState(() => _bufferMinutes = v),
                      ).animate(delay: 80.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 14),
                      PremiumButton(
                        label: req == null
                            ? 'Find best time'
                            : 'Update recommendation',
                        icon: Icons.schedule_rounded,
                        variant: PremiumButtonVariant.accent,
                        onPressed: _runAnalysis,
                      ),
                      const SizedBox(height: 18),
                      if (req != null) _ResultsSection(
                        request: req,
                        targetArrival: _activeDeadline ?? _arrival,
                        onNotify: _notifyMe,
                        onStartNavigation: _startNavigation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(8),
            borderRadius: 14,
            blur: 36,
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arrive on time',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Choose when you need to arrive, and we'll suggest when to leave.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({required this.origin, required this.destination});
  final Place origin;
  final Place destination;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      borderRadius: 18,
      blur: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Row(
            icon: Icons.location_on_rounded,
            iconColor: scheme.error,
            label: 'Destination',
            text: destination.name,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(
              height: 12,
              child: VerticalDivider(
                width: 12,
                thickness: 1.2,
                color: scheme.outlineVariant,
              ),
            ),
          ),
          _Row(
            icon: Icons.trip_origin_rounded,
            iconColor: scheme.primary,
            label: 'From',
            text: origin.name,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.text,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultsSection extends ConsumerWidget {
  const _ResultsSection({
    required this.request,
    required this.targetArrival,
    required this.onNotify,
    required this.onStartNavigation,
  });
  final BestTimeRequest request;
  final DateTime targetArrival;
  final ValueChanged<TimeSuggestion> onNotify;
  final VoidCallback onStartNavigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bestTimeProvider(request));
    return async.when(
      loading: () => const _LoadingState(),
      error: (e, _) => _ErrorState(
        error: e.toString(),
        onRetry: () => ref.invalidate(bestTimeProvider(request)),
      ),
      data: (result) {
        if (!result.isReady) {
          return const _InitializingState();
        }
        if (result.suggestions.isEmpty) {
          return const _EmptyState();
        }
        return _SuggestionsList(
          result: result,
          targetArrival: targetArrival,
          onNotify: onNotify,
          onStartNavigation: onStartNavigation,
        );
      },
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({
    required this.result,
    required this.targetArrival,
    required this.onNotify,
    required this.onStartNavigation,
  });
  final BestTimeResult result;
  final DateTime targetArrival;
  final ValueChanged<TimeSuggestion> onNotify;
  final VoidCallback onStartNavigation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recommended = result.recommended;
    final others =
        result.suggestions.where((s) => !s.isRecommended).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recommended != null)
          TimeSuggestionCard.recommended(
            suggestion: recommended,
            targetArrival: targetArrival,
            onNotify: () => onNotify(recommended),
            onStartNavigation: onStartNavigation,
          )
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.06, end: 0),
        const SizedBox(height: 18),
        if (others.isNotEmpty) ...[
          Text(
            'Compare options'.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < others.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TimeSuggestionCard(
                suggestion: others[i],
                targetArrival: targetArrival,
              )
                  .animate(delay: (90 * i).ms)
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0),
            ),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${result.routeDistanceKm.toStringAsFixed(1)} km · '
                  'traffic preview',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(20),
          borderRadius: 24,
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                      size: 22, color: Colors.white)
                  .animate(onPlay: (c) => c.repeat())
                  .rotate(duration: 1800.ms),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Checking the best departure windows…',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ShimmerLoader(
          height: 110,
          borderRadius: 18,
          backgroundColor: AppColors.glassFillLight(brightness),
        ),
        const SizedBox(height: 12),
        ShimmerLoader(
          height: 110,
          borderRadius: 18,
          backgroundColor: AppColors.glassFillLight(brightness),
        ),
        const SizedBox(height: 12),
        ShimmerLoader(
          height: 110,
          borderRadius: 18,
          backgroundColor: AppColors.glassFillLight(brightness),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'This usually takes a moment.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _InitializingState extends StatelessWidget {
  const _InitializingState();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 18,
      blur: 24,
      child: Column(
        children: [
          Icon(Icons.cloud_sync_rounded, size: 40, color: scheme.primary),
          const SizedBox(height: 12),
          Text('Predictions are getting ready…',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 6),
          Text(
            "Try again shortly, or use the preview once it appears.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 18,
      blur: 24,
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 40, color: scheme.error),
          const SizedBox(height: 12),
          Text("Couldn't load recommendations",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          PremiumButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
            expand: false,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 18,
      blur: 24,
      child: Column(
        children: [
          Icon(Icons.schedule_rounded, size: 40, color: scheme.primary),
          const SizedBox(height: 12),
          Text('No useful suggestions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 6),
          Text(
            'Try widening your search window or adjusting the deadline.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
