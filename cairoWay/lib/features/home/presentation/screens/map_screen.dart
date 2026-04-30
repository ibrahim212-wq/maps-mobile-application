import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/incident.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../shared/widgets/animated_bottom_sheet.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/home_prompt_provider.dart';
import '../providers/map_layer_provider.dart';
import '../providers/map_state_provider.dart';
import '../widgets/home_bottom_sheet.dart';
import '../widgets/home_work_prompt_sheet.dart';
import '../widgets/map_floating_controls.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/map_view.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapViewController? _map;
  bool _signalsLoaded = false;
  UserLocation? _userLoc;

  bool _promptShownThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _resolveLocation();
    });
  }

  /// Reactive check: only show the prompt if not already dismissed AND the
  /// user has neither Home nor Work saved.
  void _maybeShowHomeWorkPrompt() {
    if (_promptShownThisSession) return;
    final dismissed = ref.read(homeWorkPromptDismissedProvider);
    if (dismissed) return;
    final storage = ref.read(storageServiceProvider);
    final hasAnyPlace = storage.savedByLabel('home') != null ||
        storage.savedByLabel('work') != null;
    if (hasAnyPlace) {
      // Auto-dismiss for users who already saved a place.
      ref.read(homeWorkPromptDismissedProvider.notifier).dismiss();
      return;
    }
    _promptShownThisSession = true;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      HomeWorkPromptSheet.show(context);
    });
  }

  Future<void> _resolveLocation() async {
    final loc = await ref.read(locationServiceProvider).currentLocation();
    if (!mounted || loc == null) return;
    setState(() => _userLoc = loc);
    await _map?.flyTo(loc.lat, loc.lng, zoom: 15);
    await _loadSignalsAroundUser();
  }

  Future<void> _loadSignalsAroundUser() async {
    if (_signalsLoaded || _userLoc == null || _map == null) return;
    if (!ref.read(showTrafficSignalsProvider)) return;
    final loc = _userLoc!;
    const r = 0.04; // ~ 4km
    final signals = await ref.read(trafficSignalsProvider(
      Bbox(loc.lat - r, loc.lng - r, loc.lat + r, loc.lng + r),
    ).future);
    if (!mounted) return;
    await _map?.drawTrafficSignals(signals);
    _signalsLoaded = true;
  }

  Future<void> _recenter() async {
    HapticFeedback.mediumImpact();
    final loc = _userLoc ??
        await ref.read(locationServiceProvider).currentLocation();
    if (!mounted || loc == null || _map == null) {
      _toast('Location unavailable. Check permissions.');
      return;
    }
    setState(() => _userLoc = loc);
    await _map!.recenter(loc.lat, loc.lng);
    await _loadSignalsAroundUser();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleSignals() async {
    final ctrl = ref.read(showTrafficSignalsProvider.notifier);
    final next = !ctrl.state;
    ctrl.state = next;
    if (!next) {
      await _map?.drawTrafficSignals(const []);
      _signalsLoaded = false;
    } else {
      await _loadSignalsAroundUser();
    }
  }

  Future<void> _openIncidentSheet() async {
    final loc = _userLoc;
    if (loc == null) {
      _toast('Waiting for location…');
      return;
    }
    await showPremiumSheet(
      context: context,
      builder: (ctx) => _IncidentSheet(
        lat: loc.lat,
        lng: loc.lng,
        onSubmit: (type, note) async {
          await ref.read(storageServiceProvider).addIncident(
                type: type,
                lat: loc.lat,
                lng: loc.lng,
                note: note,
              );
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
          _toast('Reported. Thank you!');
        },
      ),
    );
  }

  Future<void> _openLayersSheet() async {
    await showPremiumSheet(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final showSignals = ref.watch(showTrafficSignalsProvider);
        final showTraffic = ref.watch(showTrafficLayerProvider);
        final selectedLayer = ref.watch(mapLayerProvider);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetTitle('Map type',
                  subtitle: 'Choose your preferred basemap'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final layer in MapLayer.values) ...[
                    Expanded(
                      child: _LayerCard(
                        layer: layer,
                        selected: selectedLayer == layer,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(mapLayerProvider.notifier).set(layer);
                        },
                      ),
                    ),
                    if (layer != MapLayer.values.last) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              const SheetTitle('Overlays',
                  subtitle: 'Toggle what you see on top'),
              SwitchListTile(
                value: showTraffic,
                onChanged: (v) =>
                    ref.read(showTrafficLayerProvider.notifier).state = v,
                title: const Text('Traffic congestion'),
                subtitle:
                    const Text('Color-coded congestion on selected routes'),
                secondary: const Icon(Icons.traffic_rounded),
              ),
              SwitchListTile(
                value: showSignals,
                onChanged: (v) async {
                  ref.read(showTrafficSignalsProvider.notifier).state = v;
                  if (v) {
                    await _loadSignalsAroundUser();
                  } else {
                    await _map?.drawTrafficSignals(const []);
                    _signalsLoaded = false;
                  }
                },
                title: const Text('Traffic signals'),
                subtitle: const Text('OpenStreetMap signal points'),
                secondary: const Icon(Icons.brightness_1, size: 18),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// Re-applies all custom layers after the basemap style finishes loading.
  /// Mapbox wipes sources/layers on every style switch, so we re-add them.
  Future<void> _onStyleLoaded() async {
    _signalsLoaded = false;
    if (ref.read(showTrafficSignalsProvider)) {
      await _loadSignalsAroundUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final showTraffic = ref.watch(showTrafficLayerProvider);
    final showSignals = ref.watch(showTrafficSignalsProvider);
    // Reactively gate the home/work prompt on the dismissed flag.
    ref.watch(homeWorkPromptDismissedProvider);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowHomeWorkPrompt());

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              brightness: brightness,
              initialLat: _userLoc?.lat,
              initialLng: _userLoc?.lng,
              layer: ref.watch(mapLayerProvider),
              onStyleLoaded: _onStyleLoaded,
              onMapReady: (controller) {
                _map = controller;
                if (_userLoc != null) {
                  controller.flyTo(_userLoc!.lat, _userLoc!.lng, zoom: 15);
                }
                _loadSignalsAroundUser();
              },
            ),
          ),
          // Top search bar
          Align(
            alignment: Alignment.topCenter,
            child: MapSearchBar(onProfileTap: _openLayersSheet),
          ),
          // Right side floating controls — pushed clear of the peek sheet.
          Positioned(
            right: 16,
            bottom: _peekClearance(context) + 12,
            child: MapFloatingControls(
              onRecenter: _recenter,
              onToggleTraffic: () =>
                  ref.read(showTrafficLayerProvider.notifier).state =
                      !showTraffic,
              onToggleSignals: _toggleSignals,
              onLayers: _openLayersSheet,
              trafficOn: showTraffic,
              signalsOn: showSignals,
            ),
          ),
          // Incident report FAB (left side)
          Positioned(
            left: 16,
            bottom: _peekClearance(context) + 12,
            child: GlassContainer.pill(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: _openIncidentSheet,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.report_gmailerrorred_rounded,
                      color: Theme.of(context).colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Text('Report',
                      style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms).slideX(begin: -0.2),
          ),
          // Persistent draggable home sheet (peek + expand to ~50%).
          const HomeBottomSheet(bottomNavHeight: _bottomNavHeight),
        ],
      ),
    );
  }

  static const double _bottomNavHeight = 70;

  /// Vertical clearance above the peek sheet so floating buttons never
  /// overlap the greeting card.
  double _peekClearance(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Peek = ~150 logical px content + nav + safe-area.
    return 150 + _bottomNavHeight + mq.padding.bottom;
  }
}

class _IncidentSheet extends StatefulWidget {
  const _IncidentSheet({
    required this.lat,
    required this.lng,
    required this.onSubmit,
  });
  final double lat;
  final double lng;
  final Future<void> Function(IncidentType type, String? note) onSubmit;

  @override
  State<_IncidentSheet> createState() => _IncidentSheetState();
}

class _IncidentSheetState extends State<_IncidentSheet> {
  IncidentType? _selected;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetTitle('Report an incident',
              subtitle: 'Help others avoid trouble — one tap.'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in IncidentType.values)
                ChoiceChip(
                  label: Text('${t.emoji}  ${t.label}'),
                  selected: _selected == t,
                  onSelected: (_) => setState(() => _selected = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Add a note (optional)',
            ),
          ),
          const SizedBox(height: 18),
          PremiumButton(
            label: 'Submit',
            icon: Icons.send_rounded,
            onPressed: _selected == null
                ? null
                : () => widget.onSubmit(
                      _selected!,
                      _noteCtrl.text.trim().isEmpty
                          ? null
                          : _noteCtrl.text.trim(),
                    ),
          ),
        ],
      ),
    );
  }
}

/// Compact branded card used in the layers sheet to pick a basemap.
/// Shows an emerald gradient when selected, neutral surface otherwise.
class _LayerCard extends StatelessWidget {
  const _LayerCard({
    required this.layer,
    required this.selected,
    required this.onTap,
  });

  final MapLayer layer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            color: selected ? null : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : scheme.outline.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.lightPrimary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                layer.icon,
                size: 26,
                color: selected ? Colors.white : scheme.onSurface,
              ),
              const SizedBox(height: 8),
              Text(
                layer.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: selected ? Colors.white : scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
