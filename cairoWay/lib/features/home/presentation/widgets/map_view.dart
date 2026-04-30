import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/route_option.dart';

/// Visual variants for the embedded map. `standard` = bright Mapbox style for
/// browsing; `navigation` = optimized navigation-day/night style with 3D
/// tilt for turn-by-turn navigation.
enum MapStyleVariant { standard, navigation }

/// User-selectable map basemap layer. Preserved across app restarts.
/// - [defaultStyle]: branded RouteMind light/dark map (clean Mapbox style).
/// - [satellite]: Mapbox satellite-streets imagery for landmarks/buildings.
/// - [traffic]: navigation-day/night style with built-in traffic emphasis.
enum MapLayer { defaultStyle, satellite, traffic }

extension MapLayerLabel on MapLayer {
  String get label => switch (this) {
        MapLayer.defaultStyle => 'Default',
        MapLayer.satellite => 'Satellite',
        MapLayer.traffic => 'Traffic',
      };
  String get description => switch (this) {
        MapLayer.defaultStyle => 'Clean RouteMind branded map',
        MapLayer.satellite => 'Real satellite imagery + streets',
        MapLayer.traffic => 'Live traffic & navigation-optimized',
      };
  IconData get icon => switch (this) {
        MapLayer.defaultStyle => Icons.map_rounded,
        MapLayer.satellite => Icons.satellite_alt_rounded,
        MapLayer.traffic => Icons.traffic_rounded,
      };
  String get storageKey => 'map_layer_v1';
}

/// Hosts the Mapbox map and exposes high-level controls.
class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.brightness,
    required this.onMapReady,
    this.initialLat,
    this.initialLng,
    this.initialZoom,
    this.initialPitch,
    this.initialBearing,
    this.onCameraChanged,
    this.onStyleLoaded,
    this.variant = MapStyleVariant.standard,
    this.layer = MapLayer.defaultStyle,
  });

  final Brightness brightness;
  final double? initialLat;
  final double? initialLng;
  final double? initialZoom;
  final double? initialPitch;
  final double? initialBearing;
  final MapStyleVariant variant;
  final MapLayer layer;
  final ValueChanged<MapViewController> onMapReady;
  final ValueChanged<mb.CameraState>? onCameraChanged;
  /// Fires after every style finishes loading (initial AND switches).
  /// Use this to re-add custom sources/layers (route, signals, markers)
  /// because Mapbox clears them when the basemap changes.
  final VoidCallback? onStyleLoaded;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  mb.MapboxMap? _map;
  late MapViewController _controller;

  @override
  void didUpdateWidget(covariant MapView old) {
    super.didUpdateWidget(old);
    if ((old.brightness != widget.brightness ||
            old.variant != widget.variant ||
            old.layer != widget.layer) &&
        _map != null) {
      _map!.loadStyleURI(
          _styleFor(widget.brightness, widget.variant, widget.layer));
    }
  }

  String _styleFor(Brightness b, MapStyleVariant v, MapLayer layer) {
    // Satellite always wins over variant — premium imagery view.
    if (layer == MapLayer.satellite) {
      return 'mapbox://styles/mapbox/satellite-streets-v12';
    }
    // Traffic layer or active navigation → navigation styles (built-in traffic).
    if (layer == MapLayer.traffic || v == MapStyleVariant.navigation) {
      return b == Brightness.dark
          ? 'mapbox://styles/mapbox/navigation-night-v1'
          : 'mapbox://styles/mapbox/navigation-day-v1';
    }
    return b == Brightness.dark
        ? mb.MapboxStyles.DARK
        : mb.MapboxStyles.LIGHT;
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.initialLat ?? AppConstants.defaultLat;
    final lng = widget.initialLng ?? AppConstants.defaultLng;
    final zoom = widget.initialZoom ?? AppConstants.defaultZoom;

    return mb.MapWidget(
      key: ValueKey('routemind-map-${widget.variant.name}'),
      styleUri: _styleFor(widget.brightness, widget.variant, widget.layer),
      onStyleLoadedListener: (_) {
        // Mapbox wipes all custom sources/layers when the basemap changes.
        // Notify the host so it can re-draw route/signals/markers.
        widget.onStyleLoaded?.call();
      },
      cameraOptions: mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(lng, lat)),
        zoom: zoom,
        pitch: widget.initialPitch ?? 0,
        bearing: widget.initialBearing ?? 0,
      ),
      onMapCreated: (controller) async {
        _map = controller;
        // Hide attribution & scale-bar clutter for a cleaner UI; keep logo.
        await controller.attribution
            .updateSettings(mb.AttributionSettings(enabled: false));
        await controller.scaleBar
            .updateSettings(mb.ScaleBarSettings(enabled: false));
        await controller.logo
            .updateSettings(mb.LogoSettings(marginBottom: 110, marginLeft: 12));
        await controller.compass
            .updateSettings(mb.CompassSettings(enabled: false));

        // Premium navigation puck — emerald green arrow with heading
        await controller.location.updateSettings(mb.LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: 0xFF0E9F6E,
          showAccuracyRing: true,
          accuracyRingColor: 0x330E9F6E,
          accuracyRingBorderColor: 0xFF0E9F6E,
          // Enable bearing-aware arrow puck for navigation
          puckBearingEnabled: true,
        ));

        _controller = MapViewController._(controller);
        widget.onMapReady(_controller);
      },
      onCameraChangeListener: widget.onCameraChanged == null
          ? null
          : (_) async {
              final cam = await _map?.getCameraState();
              if (cam != null) widget.onCameraChanged!(cam);
            },
    );
  }
}

/// Thin wrapper around MapboxMap exposing only the high-level operations
/// the rest of the app needs.
class MapViewController {
  MapViewController._(this._map);
  final mb.MapboxMap _map;

  mb.MapboxMap get raw => _map;

  Future<void> flyTo(double lat, double lng, {double zoom = 15}) async {
    await _map.flyTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(lng, lat)),
        zoom: zoom,
      ),
      mb.MapAnimationOptions(duration: 900, startDelay: 0),
    );
  }

  /// Tilted "following" camera for active navigation. Bearing rotates the
  /// map so the direction of travel is up.
  Future<void> followUser(
    double lat,
    double lng, {
    double zoom = 17,
    double pitch = 60,
    double? bearing,
    int durationMs = 600,
  }) async {
    await _map.easeTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(lng, lat)),
        zoom: zoom,
        pitch: pitch,
        bearing: bearing,
      ),
      mb.MapAnimationOptions(duration: durationMs, startDelay: 0),
    );
  }

  Future<void> recenter(double lat, double lng) async {
    await _map.easeTo(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(lng, lat)),
        zoom: 16,
        bearing: 0,
        pitch: 0,
      ),
      mb.MapAnimationOptions(duration: 700, startDelay: 0),
    );
  }

  /// Fit the camera to cover the given coordinates with padding.
  Future<void> fitBounds(List<List<double>> coordinates) async {
    if (coordinates.isEmpty) return;
    double minLng = coordinates.first[0],
        maxLng = coordinates.first[0],
        minLat = coordinates.first[1],
        maxLat = coordinates.first[1];
    for (final p in coordinates) {
      if (p[0] < minLng) minLng = p[0];
      if (p[0] > maxLng) maxLng = p[0];
      if (p[1] < minLat) minLat = p[1];
      if (p[1] > maxLat) maxLat = p[1];
    }
    final cam = await _map.cameraForCoordinateBounds(
      mb.CoordinateBounds(
        southwest: mb.Point(coordinates: mb.Position(minLng, minLat)),
        northeast: mb.Point(coordinates: mb.Position(maxLng, maxLat)),
        infiniteBounds: false,
      ),
      mb.MbxEdgeInsets(top: 120, left: 60, bottom: 280, right: 60),
      0,
      0,
      null,
      null,
    );
    await _map.flyTo(
      cam,
      mb.MapAnimationOptions(duration: 900, startDelay: 0),
    );
  }

  // ─── Routes ───
  static const _routeSourceId = 'rm-route-src';
  static const _routeLayerCasing = 'rm-route-casing';
  static const _routeLayerId = 'rm-route-line';
  static const _altRouteSourceId = 'rm-alt-route-src';
  static const _altRouteLayerId = 'rm-alt-route-line';
  // Traveled (already-passed) segment of the active route. Rendered as a
  // dim, muted line to indicate progress like Google/Apple Maps.
  static const _traveledSourceId = 'rm-route-traveled-src';
  static const _traveledLayerId = 'rm-route-traveled-line';

  Future<void> drawRoute(RouteOption route,
      {Color color = const Color(0xFF16D6A3)}) async {
    final geo = _lineString(route.geometry);
    await _ensureSource(_routeSourceId, geo);
    // Initialize the traveled source as an empty FeatureCollection so the
    // layer renders nothing until we have actual progress data.
    await _ensureSource(_traveledSourceId, _emptyFeatureCollection());
    // Premium route rendering — layered for depth:
    //   1. Traveled (dim grey) — passed segments
    //   2. Dark casing (outline for contrast on any basemap)
    //   3. Vivid main line (emerald brand) — remaining route
    // All layers use rounded caps/joins and zoom-based widths so the line
    // stays crisp from city overview down to street level.
    await _ensurePremiumLineLayer(_traveledLayerId, _traveledSourceId,
        color: 0xFF6B7280, // muted slate grey
        widthExpression: _zoomWidth(min: 4, max: 12),
        opacity: 0.45);
    await _ensurePremiumLineLayer(_routeLayerCasing, _routeSourceId,
        color: 0xFF073B32,
        widthExpression: _zoomWidth(min: 6, max: 16),
        opacity: 0.95);
    await _ensurePremiumLineLayer(_routeLayerId, _routeSourceId,
        color: color.toARGB32(),
        widthExpression: _zoomWidth(min: 3.5, max: 11),
        opacity: 1.0);
  }

  /// Updates the visible split between traveled (dim) and remaining (bright)
  /// route segments. Call this on every location update during navigation
  /// so the user sees passed roads fade out, like Google Maps.
  Future<void> setRouteProgress({
    required List<List<double>> traveled,
    required List<List<double>> remaining,
  }) async {
    // GeoJSON LineStrings require ≥ 2 coords; fall back to empty
    // FeatureCollection when a segment is degenerate.
    final remainingData =
        remaining.length >= 2 ? _lineString(remaining) : _emptyFeatureCollection();
    final traveledData =
        traveled.length >= 2 ? _lineString(traveled) : _emptyFeatureCollection();
    if (await _map.style.styleSourceExists(_routeSourceId)) {
      await _map.style
          .setStyleSourceProperty(_routeSourceId, 'data', jsonEncode(remainingData));
    }
    if (await _map.style.styleSourceExists(_traveledSourceId)) {
      await _map.style
          .setStyleSourceProperty(_traveledSourceId, 'data', jsonEncode(traveledData));
    }
  }

  Future<void> drawAlternative(RouteOption route) async {
    final geo = _lineString(route.geometry);
    await _ensureSource(_altRouteSourceId, geo);
    await _ensurePremiumLineLayer(_altRouteLayerId, _altRouteSourceId,
        color: 0xCC4A8A7E,
        widthExpression: _zoomWidth(min: 2.5, max: 7),
        opacity: 0.55);
  }

  /// Mapbox expression: linearly interpolate line width by zoom level so the
  /// route looks slim at low zoom and thick at street level — matches the
  /// way Google Maps scales its blue route line.
  List<Object> _zoomWidth({required double min, required double max}) {
    return <Object>[
      'interpolate',
      ['linear'],
      ['zoom'],
      8,
      min,
      14,
      (min + max) / 2,
      18,
      max,
    ];
  }

  Future<void> clearRoutes() async {
    await _removeLayerIfExists(_routeLayerCasing);
    await _removeLayerIfExists(_routeLayerId);
    await _removeLayerIfExists(_traveledLayerId);
    await _removeLayerIfExists(_altRouteLayerId);
    await _removeSourceIfExists(_routeSourceId);
    await _removeSourceIfExists(_traveledSourceId);
    await _removeSourceIfExists(_altRouteSourceId);
  }

  // ─── Traffic signals ───
  static const _signalsSourceId = 'rm-signals-src';
  static const _signalsLayerId = 'rm-signals-layer';

  Future<void> drawTrafficSignals(List<List<double>> points) async {
    if (points.isEmpty) {
      await _removeLayerIfExists(_signalsLayerId);
      await _removeSourceIfExists(_signalsSourceId);
      return;
    }
    final fc = {
      'type': 'FeatureCollection',
      'features': [
        for (final p in points)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [p[0], p[1]],
            },
            'properties': <String, dynamic>{},
          }
      ],
    };
    await _ensureSource(_signalsSourceId, fc);
    final exists = await _map.style.styleLayerExists(_signalsLayerId);
    if (!exists) {
      await _map.style.addLayer(mb.CircleLayer(
        id: _signalsLayerId,
        sourceId: _signalsSourceId,
        circleRadius: 4,
        circleColor: 0xFFFFC107,
        circleStrokeColor: 0xFF202020,
        circleStrokeWidth: 1.2,
        circleOpacity: 0.9,
        minZoom: 12,
      ));
    }
  }

  // ─── helpers ───
  Map<String, dynamic> _lineString(List<List<double>> coords) => {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': coords,
        },
        'properties': <String, dynamic>{},
      };

  /// Empty GeoJSON used as the source data when a route segment has no
  /// drawable points yet (e.g. traveled segment at navigation start).
  Map<String, dynamic> _emptyFeatureCollection() => {
        'type': 'FeatureCollection',
        'features': const <dynamic>[],
      };

  Future<void> _ensureSource(String id, Map<String, dynamic> geojson) async {
    final exists = await _map.style.styleSourceExists(id);
    final data = jsonEncode(geojson);
    if (exists) {
      await _map.style.setStyleSourceProperty(id, 'data', data);
    } else {
      await _map.style.addSource(mb.GeoJsonSource(id: id, data: data));
    }
  }


  /// Premium line layer using a Mapbox zoom-interpolated width expression
  /// (`interpolate [linear] [zoom] ...`) so the route stays crisp at every
  /// zoom level. Adds rounded caps/joins for a smooth, premium look.
  Future<void> _ensurePremiumLineLayer(
    String id,
    String sourceId, {
    required int color,
    required List<Object> widthExpression,
    required double opacity,
  }) async {
    final widthJson = jsonEncode(widthExpression);
    if (await _map.style.styleLayerExists(id)) {
      // Update color/width on existing layer (style switch path).
      await _map.style.setStyleLayerProperty(
          id, 'line-color', jsonEncode(_hexFromArgb(color)));
      await _map.style.setStyleLayerProperty(id, 'line-width', widthJson);
      await _map.style
          .setStyleLayerProperty(id, 'line-opacity', jsonEncode(opacity));
      return;
    }
    await _map.style.addLayer(mb.LineLayer(
      id: id,
      sourceId: sourceId,
      lineColor: color,
      lineOpacity: opacity,
      lineCap: mb.LineCap.ROUND,
      lineJoin: mb.LineJoin.ROUND,
    ));
    // Apply the zoom-based width expression after creation.
    await _map.style.setStyleLayerProperty(id, 'line-width', widthJson);
  }

  String _hexFromArgb(int argb) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final a = ((argb >> 24) & 0xFF) / 255.0;
    return 'rgba($r, $g, $b, ${a.toStringAsFixed(3)})';
  }

  Future<void> _removeLayerIfExists(String id) async {
    if (await _map.style.styleLayerExists(id)) {
      await _map.style.removeStyleLayer(id);
    }
  }

  Future<void> _removeSourceIfExists(String id) async {
    if (await _map.style.styleSourceExists(id)) {
      await _map.style.removeStyleSource(id);
    }
  }
}
