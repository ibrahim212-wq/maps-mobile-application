import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Visibility;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../controllers/navigation_controller.dart';
import '../../models/navigation_route.dart';
import 'navigation_map_host_base.dart' show kNavCasing, kNavDest, kNavDestLayer, kNavLine, kNavRemaining;

/// Mapbox map + route layers (Android / iOS / desktop; not `dart.library.html`).
class NavigationMapHost extends StatefulWidget {
  const NavigationMapHost({
    super.key,
    required this.controller,
    required this.destinationLat,
    required this.destinationLng,
    required this.onUserPan,
  });

  final NavigationController controller;
  final double destinationLat;
  final double destinationLng;
  final VoidCallback onUserPan;

  @override
  State<NavigationMapHost> createState() => _NavigationMapHostState();
}

class _NavigationMapHostState extends State<NavigationMapHost> {
  MapboxMap? _map;
  var _styleReady = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    unawaited(_syncMapFromController());
  }

  Future<void> _syncMapFromController() async {
    final map = _map;
    if (map == null || !_styleReady) return;
    final r = widget.controller.route;
    if (r == null) return;
    try {
      if (widget.controller.isNavigating) {
        final json = r.toRemainingGeoJsonFromIndex(
          widget.controller.remainingPathStartIndex,
        );
        await map.style.setStyleSourceProperty(kNavRemaining, 'data', json);
      } else {
        await map.style.setStyleSourceProperty(
          kNavRemaining,
          'data',
          r.toFullRouteGeoJson(),
        );
      }
    } on Object {
      // Style may be reloading; ignore.
    }
    if (widget.controller.followUser &&
        widget.controller.isNavigating &&
        widget.controller.lastPosition != null) {
      unawaited(_followCamera(widget.controller.lastPosition!));
    }
  }

  Future<void> _followCamera(geo.Position pos) async {
    final map = _map;
    if (map == null) return;
    final lng = pos.longitude;
    final lat = pos.latitude;
    double? bearing;
    if (pos.heading > 1 && pos.heading < 359) {
      bearing = pos.heading;
    }
    final route = widget.controller.route;
    if (bearing == null && route != null && widget.controller.currentStepIndex < route.steps.length) {
      final s = route.steps[widget.controller.currentStepIndex];
      bearing = _bearingDeg(lat, lng, s.maneuverLat, s.maneuverLng);
    }
    try {
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: 17,
          bearing: bearing,
          pitch: 55,
        ),
        MapAnimationOptions(duration: 350, startDelay: 0),
      );
    } on Object {
      // ignore
    }
  }

  static double _bearingDeg(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLon = (lon2 - lon1) * math.pi / 180;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final y = math.sin(dLon) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) -
        math.sin(p1) * math.cos(p2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData d) async {
    final map = _map;
    if (map == null) return;
    _styleReady = true;
    try {
      await _ensureNavLayers(map);
    } on Object {
      // hot reload: layers may already exist
    }
    if (widget.controller.route != null) {
      await _fitRoute(map, widget.controller.route!);
    }
    await _syncMapFromController();
  }

  Future<void> _ensureNavLayers(MapboxMap map) async {
    try {
      await map.style.addSource(GeoJsonSource(id: kNavRemaining, data: ''));
    } on Object {
      // Idempotent: source may already exist (hot restart).
    }
    try {
      await map.style.addLayer(
        LineLayer(
          id: kNavCasing,
          sourceId: kNavRemaining,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineColor: 0xFFFFFFFF,
          lineWidth: 9,
          lineOpacity: 0.85,
        ),
      );
    } on Object {
      // Idempotent: casing layer may already exist.
    }
    try {
      await map.style.addLayer(
        LineLayer(
          id: kNavLine,
          sourceId: kNavRemaining,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineColor: 0xFF1A73E8,
          lineWidth: 5.5,
          lineOpacity: 0.95,
        ),
      );
    } on Object {
      // Idempotent: main line may already exist.
    }
    final dest =
        '{"type":"Feature","properties":{},"geometry":{"type":"Point","coordinates":[${widget.destinationLng},${widget.destinationLat}]}}';
    try {
      await map.style.addSource(GeoJsonSource(id: kNavDest, data: dest));
    } on Object {
      // Idempotent: destination point source may already exist.
    }
    try {
      await map.style.addLayer(
        CircleLayer(
          id: kNavDestLayer,
          sourceId: kNavDest,
          circleRadius: 9,
          circleColor: 0xFFE53935,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2.5,
        ),
      );
    } on Object {
      // Idempotent: destination layer may already exist.
    }
  }

  Future<void> _fitRoute(MapboxMap map, NavigationRoute r) async {
    final coords = r.coordinates;
    if (coords.isEmpty) return;
    var pts = coords
        .map(
          (e) => Point(
            coordinates: Position(e[0], e[1]),
          ),
        )
        .toList();
    if (pts.length > 120) {
      final step = (pts.length / 120).ceil();
      pts = [
        for (var i = 0; i < pts.length; i += step) pts[i],
        pts.last,
      ];
    }
    final pad = MbxEdgeInsets(
      top: 120,
      left: 36,
      bottom: 220,
      right: 36,
    );
    final opt = await map.cameraForCoordinatesPadding(
      pts,
      CameraOptions(),
      pad,
      16,
      null,
    );
    try {
      await map.flyTo(
        opt,
        MapAnimationOptions(duration: 1200, startDelay: 0),
      );
    } on Object {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('routemindNavigationMap'),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      textureView: true,
      viewport: CameraViewportState(
        center: Point(
          coordinates: Position(
            widget.destinationLng,
            widget.destinationLat,
          ),
        ),
        zoom: 13,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
      onScrollListener: (_) {
        widget.onUserPan();
      },
    );
  }
}
