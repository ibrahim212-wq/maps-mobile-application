import 'dart:async';

import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../providers/home_map_providers.dart';
import '../../services/osm_traffic_signals_service.dart';
import 'home_map_view.dart';

/// Full-screen Mapbox map (iOS / Android / desktop — not `package:flutter/foundation` web).
class HomeMapMapboxView extends ConsumerStatefulWidget {
  const HomeMapMapboxView({super.key});

  @override
  ConsumerState<HomeMapMapboxView> createState() => _HomeMapMapboxViewState();
}

class _HomeMapMapboxViewState extends ConsumerState<HomeMapMapboxView> {
  static const _trafficSourceId = 'routemind-traffic-source';
  static const _trafficLayerId = 'routemind-traffic-layer';
  static const _signalSourceId = 'routemind-signal-source';
  static const _signalLayerId = 'routemind-signal-layer';

  MapboxMap? _map;
  final _osm = OsmTrafficSignalsService();
  var _didLoadSignals = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(trafficOverlayEnabledProvider, (prev, on) {
      unawaited(_setTrafficLayerVisible(on));
    });

    return MapWidget(
      key: const ValueKey('routemindHomeMap'),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      textureView: true,
      viewport: CameraViewportState(
        center: Point(
          coordinates: Position(HomeMapView.cairoLng, HomeMapView.cairoLat),
        ),
        zoom: 12.5,
        bearing: 0,
        pitch: 0,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await _enableUserLocation();
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    final map = _map;
    if (map == null) return;
    final trafficOn = ref.read(trafficOverlayEnabledProvider);
    await _ensureTrafficLayer(map, trafficOn);
    if (!_didLoadSignals) {
      _didLoadSignals = true;
      unawaited(_addOsmTrafficSignals(map));
    }
  }

  Future<void> _enableUserLocation() async {
    var perm = await geo.Geolocator.checkPermission();
    if (perm == geo.LocationPermission.denied) {
      perm = await geo.Geolocator.requestPermission();
    }
    final map = _map;
    if (map == null) return;
    if (perm == geo.LocationPermission.denied ||
        perm == geo.LocationPermission.deniedForever) {
      return;
    }
    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: 0xFF1A73E8,
        showAccuracyRing: true,
        accuracyRingColor: 0x401A73E8,
        accuracyRingBorderColor: 0x661A73E8,
        puckBearingEnabled: true,
      ),
    );
    try {
      final geo.Position pos = await geo.Geolocator.getCurrentPosition();
      if (!mounted) return;
      await map.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              pos.longitude,
              pos.latitude,
            ),
          ),
          zoom: 14,
        ),
        MapAnimationOptions(duration: 1500, startDelay: 0),
      );
    } on Object {
      // Map puck may still work from the native stack without flyTo.
    }
  }

  Future<void> _ensureTrafficLayer(MapboxMap map, bool visible) async {
    try {
      await map.style.addSource(
        VectorSource(
          id: _trafficSourceId,
          url: 'mapbox://mapbox.mapbox-traffic-v1',
        ),
      );
    } on Object {
      // Source may already exist (hot reload / re-style).
    }
    try {
      await map.style.addLayer(
        LineLayer(
          id: _trafficLayerId,
          sourceId: _trafficSourceId,
          sourceLayer: 'traffic',
          visibility: visible ? Visibility.VISIBLE : Visibility.NONE,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineWidthExpression: [
            'interpolate',
            ['linear'],
            ['zoom'],
            14.0,
            ['*', 2.0, 1.3],
            20.0,
            ['*', 10, 1.2]
          ],
          lineColorExpression: [
            'case',
            [
              '==',
              'low',
              ['get', 'congestion']
            ],
            '#39c66d',
            [
              '==',
              'moderate',
              ['get', 'congestion']
            ],
            '#ff8c1a',
            [
              '==',
              'heavy',
              ['get', 'congestion']
            ],
            '#ff0015',
            [
              '==',
              'severe',
              ['get', 'congestion']
            ],
            '#981b25',
            '#000000'
          ],
          lineOffsetExpression: [
            'interpolate',
            ['linear'],
            ['zoom'],
            14.0,
            ['*', 2, 1.0],
            20.0,
            ['*', 18, 1.0]
          ],
        ),
      );
    } on Object {
      await _setTrafficLayerVisible(visible);
    }
  }

  Future<void> _setTrafficLayerVisible(bool visible) async {
    final map = _map;
    if (map == null) return;
    try {
      await map.style.setStyleLayerProperty(
        _trafficLayerId,
        'visibility',
        visible ? 'visible' : 'none',
      );
    } on Object {
      // Layer not present yet.
    }
  }

  Future<void> _addOsmTrafficSignals(MapboxMap map) async {
    final b = OsmTrafficSignalsService.defaultCairoBbox();
    final pts = await _osm.fetchTrafficSignalsInBbox(
      south: b.south,
      west: b.west,
      north: b.north,
      east: b.east,
    );
    if (!mounted) return;
    if (pts.isEmpty) return;
    final json = trafficSignalsToGeoJson(pts);
    try {
      await map.style.addSource(GeoJsonSource(id: _signalSourceId, data: json));
      await map.style.addLayer(
        CircleLayer(
          id: _signalLayerId,
          sourceId: _signalSourceId,
          circleRadius: 3.2,
          circleColor: 0xFFFF9800,
          circleStrokeWidth: 1.2,
          circleStrokeColor: 0xFFFFFFFF,
        ),
      );
    } on Object {
      // Ignore duplicate or style errors
    }
  }
}
