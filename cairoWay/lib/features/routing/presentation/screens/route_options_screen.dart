import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/place.dart';
import '../../../../shared/models/route_option.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/shimmer_loader.dart';
import '../../../home/presentation/providers/map_layer_provider.dart';
import '../../../home/presentation/widgets/map_view.dart';
import '../providers/routes_provider.dart';

class RouteOptionsScreen extends ConsumerStatefulWidget {
  const RouteOptionsScreen({
    super.key,
    required this.destination,
    this.origin,
  });
  final Place destination;
  final Place? origin;

  @override
  ConsumerState<RouteOptionsScreen> createState() =>
      _RouteOptionsScreenState();
}

class _RouteOptionsScreenState extends ConsumerState<RouteOptionsScreen> {
  MapViewController? _map;
  Place? _origin;
  String? _selectedId;
  bool _resolvingOrigin = true;

  @override
  void initState() {
    super.initState();
    _origin = widget.origin;
    if (_origin != null) {
      _resolvingOrigin = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolveOrigin());
    }
  }

  Future<void> _resolveOrigin() async {
    final loc = await ref.read(locationServiceProvider).currentLocation();
    if (!mounted) return;
    if (loc == null) {
      setState(() => _resolvingOrigin = false);
      return;
    }
    setState(() {
      _origin = Place(
        id: 'current',
        name: 'Current location',
        lat: loc.lat,
        lng: loc.lng,
      );
      _resolvingOrigin = false;
    });
  }

  Future<void> _drawRoutes(List<RouteOption> routes) async {
    if (_map == null || routes.isEmpty) return;
    await _map!.clearRoutes();
    final selectedId =
        _selectedId ?? routes.firstWhere((r) => r.aiPick, orElse: () => routes.first).id;
    final selected = routes.firstWhere((r) => r.id == selectedId);
    for (final r in routes) {
      if (r.id != selected.id) await _map!.drawAlternative(r);
    }
    await _map!.drawRoute(
      selected,
      color: Fmt.trafficColor(selected.trafficLevel),
    );
    await _map!.fitBounds(selected.geometry);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_resolvingOrigin) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator.adaptive()));
    }
    if (_origin == null) {
      return _NoOriginScaffold(onRetry: () {
        setState(() => _resolvingOrigin = true);
        _resolveOrigin();
      });
    }

    final query = RouteQuery(
      _origin!.lat,
      _origin!.lng,
      widget.destination.lat,
      widget.destination.lng,
    );
    final routesAsync = ref.watch(routesProvider(query));

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              brightness: brightness,
              layer: ref.watch(mapLayerProvider),
              initialLat: widget.destination.lat,
              initialLng: widget.destination.lng,
              onStyleLoaded: () {
                // Re-paint routes after a basemap switch wiped the layers.
                routesAsync.whenData(_drawRoutes);
              },
              onMapReady: (c) {
                _map = c;
                routesAsync.whenData(_drawRoutes);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.all(8),
                    borderRadius: 14,
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      borderRadius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RoutePoint(
                            icon: Icons.trip_origin_rounded,
                            text: _origin!.name,
                          ),
                          const Divider(height: 12),
                          _RoutePoint(
                            icon: Icons.location_on_rounded,
                            iconColor: Theme.of(context).colorScheme.error,
                            text: widget.destination.name,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            builder: (ctx, scroll) {
              return GlassContainer(
                borderRadius: 28,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                        Expanded(
                          child: routesAsync.when(
                            loading: () => ListView(
                              controller: scroll,
                              padding: const EdgeInsets.all(16),
                              children: const [
                                ShimmerLoader(height: 120, borderRadius: 18),
                                SizedBox(height: 12),
                                ShimmerLoader(height: 120, borderRadius: 18),
                                SizedBox(height: 12),
                                ShimmerLoader(height: 120, borderRadius: 18),
                              ],
                            ),
                            error: (e, _) => Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Could not load routes.\n$e',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            data: (routes) {
                              if (routes.isEmpty) {
                                return const Center(
                                    child: Text('No routes available right now.'));
                              }
                              final selectedId = _selectedId ??
                                  routes
                                      .firstWhere((r) => r.aiPick,
                                          orElse: () => routes.first)
                                      .id;
                              return ListView(
                                controller: scroll,
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                children: [
                                  for (var i = 0; i < routes.length; i++)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _RouteCard(
                                        route: routes[i],
                                        selected: routes[i].id == selectedId,
                                        onTap: () async {
                                          HapticFeedback.selectionClick();
                                          setState(() =>
                                              _selectedId = routes[i].id);
                                          await _drawRoutes(routes);
                                        },
                                      ).animate(delay: (80 * i).ms).fadeIn(
                                          duration: 300.ms,
                                          begin: 0).slideY(
                                          begin: 0.1, end: 0),
                                    ),
                                  const SizedBox(height: 8),
                                  PremiumButton(
                                    label: 'AI · Best time to leave',
                                    icon: Icons.schedule_rounded,
                                    variant: PremiumButtonVariant.accent,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      context.push(AppRoutes.bestTime, extra: {
                                        'origin': _origin,
                                        'destination': widget.destination,
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  PremiumButton(
                                    label: 'Start navigation',
                                    icon: Icons.navigation_rounded,
                                    onPressed: () {
                                      final route = routes.firstWhere(
                                          (r) => r.id == selectedId);
                                      context.push(AppRoutes.navigate, extra: {
                                        'route': route,
                                        'destination': widget.destination,
                                      });
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NoOriginScaffold extends StatelessWidget {
  const _NoOriginScaffold({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_rounded, size: 56),
              const SizedBox(height: 16),
              Text('Location unavailable',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                  'We need your location to compute routes. Check permissions and try again.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              PremiumButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({required this.icon, required this.text, this.iconColor});
  final IconData icon;
  final String text;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 18,
            color: iconColor ?? Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _RouteCard extends StatefulWidget {
  const _RouteCard({
    required this.route,
    required this.selected,
    required this.onTap,
  });
  final RouteOption route;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<_RouteCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final selected = widget.selected;
    final brightness = Theme.of(context).brightness;
    final isAiPick = route.aiPick;

    final aiGlow = isAiPick
        ? [
            BoxShadow(
              color: const Color(0x3300A854),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ]
        : null;

    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      scale: _pressed ? 0.98 : 1,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: Container(
          decoration: BoxDecoration(
            color: brightness == Brightness.dark
                ? const Color(0xCC0A1F14)
                : const Color(0x99F0F0F0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF50605A)
                  : const Color(0x33FFFFFF),
              width: 1.5,
            ),
            boxShadow: aiGlow ?? const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: _RouteCardBody(
                  route: route,
                  isAiPick: isAiPick,
                  levelColor: Fmt.trafficColor(route.trafficLevel),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteCardBody extends StatelessWidget {
  const _RouteCardBody({
    required this.route,
    required this.isAiPick,
    required this.levelColor,
  });
  final RouteOption route;
  final bool isAiPick;
  final Color levelColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    final badgeColor = scheme.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isAiPick)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF50605A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                            size: 14, color: Colors.white)
                        .animate(
                            onPlay: (c) => c.repeat(reverse: true))
                        .fadeIn(duration: 900.ms, begin: 0.6),
                    const SizedBox(width: 4),
                    Text('AI Pick',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: levelColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Alternative',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            const Spacer(),
            if (isAiPick)
              Text('Smart prediction',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          route.summary,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 16, color: muted),
            const SizedBox(width: 4),
            Text(
              Fmt.duration(route.durationSeconds),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 14),
            Icon(Icons.straighten_rounded, size: 16, color: muted),
            const SizedBox(width: 4),
            Text(
              Fmt.distance(route.distanceMeters),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: fg),
            ),
            const Spacer(),
            Icon(
              Fmt.trafficIcon(route.trafficLevel),
              size: 18,
              color: levelColor,
            ),
            const SizedBox(width: 4),
            Text(
              Fmt.trafficLabel(route.trafficLevel),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: levelColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        if (route.aiReason != null) ...[
          const SizedBox(height: 10),
          Text(
            route.aiReason!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: muted,
                  height: 1.4,
                ),
          ),
        ],
      ],
    );
  }
}
