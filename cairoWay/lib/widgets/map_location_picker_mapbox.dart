import 'dart:async';

import 'package:flutter/material.dart' hide Visibility;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../core/app_theme.dart';

/// Center-crosshair map (native Mapbox) — not linked on `dart.library.html` builds.
class MapboxMapCenterPane extends StatefulWidget {
  const MapboxMapCenterPane({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onMapReady,
    required this.onMapError,
  });

  final double initialLatitude;
  final double initialLongitude;

  /// Called when the style is fully loaded; [getCameraState] is reliable after this.
  final void Function(dynamic map) onMapReady;

  /// Style failed, load error, or load timeout.
  final void Function(String message) onMapError;

  @override
  State<MapboxMapCenterPane> createState() => _MapboxMapCenterPaneState();
}

class _MapboxMapCenterPaneState extends State<MapboxMapCenterPane> {
  static const _loadTimeout = Duration(seconds: 25);

  MapboxMap? _map;
  var _styleReady = false;
  Timer? _timeout;

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(_loadTimeout, () {
      if (!mounted || _styleReady) return;
      widget.onMapError(
        'The map is taking too long. You can use the default location below and continue.',
      );
    });
  }

  void _onMapCreated(MapboxMap map) {
    _map = map;
    _startTimeout();
    setState(() {});
  }

  void _onStyleLoaded(StyleLoadedEventData data) {
    final map = _map;
    if (map == null) return;
    _timeout?.cancel();
    if (!mounted) return;
    setState(() => _styleReady = true);
    widget.onMapReady(map);
  }

  void _onMapLoadError(MapLoadingErrorEventData data) {
    _timeout?.cancel();
    if (!mounted) return;
    widget.onMapError(
      data.message.isNotEmpty
          ? data.message
          : 'Could not load the map. You can use the default location below and continue.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MapWidget(
          key: const ValueKey('onboardingMap'),
          styleUri: MapboxStyles.MAPBOX_STREETS,
          textureView: true,
          viewport: CameraViewportState(
            center: Point(
              coordinates: Position(
                widget.initialLongitude,
                widget.initialLatitude,
              ),
            ),
            zoom: 12,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
          onMapLoadErrorListener: _onMapLoadError,
        ),
        const IgnorePointer(
          child: _CenterReticle(),
        ),
        if (_map != null && !_styleReady)
          const ColoredBox(
            color: Color(0x66FFFFFF),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Loading map…',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CenterReticle extends StatelessWidget {
  const _CenterReticle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            size: 44,
            color: AppColors.danger,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
          ),
        ],
      ),
    );
  }
}
