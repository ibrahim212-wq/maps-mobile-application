import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../controllers/navigation_controller.dart';
import '../core/app_theme.dart';
import 'navigation/navigation_map_host_io.dart' if (dart.library.html) 'navigation/navigation_map_host_web.dart';

/// Custom turn-by-turn: Mapbox (native) or web preview; [NavigationController] for logic.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    required this.mapboxAccessToken,
    required this.destinationLat,
    required this.destinationLng,
    this.destinationName = 'Destination',
  });

  final String mapboxAccessToken;
  final double destinationLat;
  final double destinationLng;
  final String destinationName;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late final NavigationController _c;

  @override
  void initState() {
    super.initState();
    _c = NavigationController(
      accessToken: widget.mapboxAccessToken,
      destinationLat: widget.destinationLat,
      destinationLng: widget.destinationLng,
      destinationName: widget.destinationName,
    )..addListener(_onController);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(_boot());
    });
  }

  Future<void> _boot() async {
    await _c.prepareLocation();
    if (!mounted) return;
    if (_c.errorMessage != null) {
      return;
    }
    await _c.loadRoute();
  }

  void _onController() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _c.removeListener(_onController);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      body: Stack(
        children: [
          NavigationMapHost(
            controller: c,
            destinationLat: widget.destinationLat,
            destinationLng: widget.destinationLng,
            onUserPan: () => c.setFollowUser(false),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InstructionCard(
                  isRerouting: c.isRerouting,
                  primary: c.isRerouting
                      ? 'Re-routing…'
                      : (c.route == null
                          ? (c.isLoading ? 'Loading route…' : 'Navigation')
                          : c.primaryInstruction),
                  secondary: c.isRerouting
                      ? 'Finding a new route from your position'
                      : c.secondaryText,
                  distanceMeters: c.route != null && c.isNavigating
                      ? c.distanceToNextManeuverM
                      : null,
                ),
                if (c.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ErrorBanner(message: c.errorMessage!),
                  ),
                ],
                const Spacer(),
                if (c.route != null) _BottomTripCard(c: c),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: _ActionRow(
                    c: c,
                    onRecenter: () {
                      c.recenter();
                    },
                  ),
                ),
              ],
            ),
          ),
          if (c.isLoading && c.route == null)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.primary,
    required this.secondary,
    required this.isRerouting,
    this.distanceMeters,
  });
  final String primary;
  final String secondary;
  final bool isRerouting;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        elevation: 6,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isRerouting)
                const Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Updating route',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'NEXT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                primary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: AppColors.textPrimary,
                ),
              ),
              if (distanceMeters != null && !isRerouting) ...[
                const SizedBox(height: 6),
                Text(
                  distanceMeters! >= 1000
                      ? 'in ${(distanceMeters! / 1000).toStringAsFixed(1)} km'
                      : 'in ${distanceMeters!.round()} m',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
              if (secondary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  secondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomTripCard extends StatelessWidget {
  const _BottomTripCard({required this.c});
  final NavigationController c;

  @override
  Widget build(BuildContext context) {
    final eta = c.etaSeconds;
    final m = eta ~/ 60;
    final s = eta % 60;
    final km = c.remainingDistanceM / 1000;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 8,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _chip(
                  'ETA',
                  m > 0 ? '${m}m ${s}s' : '${s}s',
                  Icons.access_time,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.textSecondary.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _chip(
                  'Left',
                  '${km.toStringAsFixed(1)} km',
                  Icons.map_outlined,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _chip(String l, String v, IconData i) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(i, size: 22, color: AppColors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              v,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.c, required this.onRecenter});
  final NavigationController c;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final canStart =
        c.route != null && !c.isLoading && !c.isNavigating;
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonal(
            onPressed: canStart ? () => unawaited(c.startNavigation()) : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Start navigation'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: c.isNavigating
                ? () => unawaited(c.stopNavigation())
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Stop'),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          elevation: 3,
          shape: const CircleBorder(),
          child: IconButton.filledTonal(
            onPressed: onRecenter,
            icon: const Icon(Icons.my_location),
            tooltip: 'Recenter',
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF3E0),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
