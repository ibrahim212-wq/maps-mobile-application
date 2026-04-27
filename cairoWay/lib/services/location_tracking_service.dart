import 'package:flutter/foundation.dart' show SynchronousFuture, kIsWeb;
import 'package:geolocator/geolocator.dart' as geo;

import '../core/platform/web_preview_state.dart';
import '../data/cairo_web_preview_data.dart';

/// High-accuracy position stream and permission checks for turn-by-turn.
class LocationTrackingService {
  LocationTrackingService();

  static const _settings = geo.LocationSettings(
    accuracy: geo.LocationAccuracy.high,
    distanceFilter: 5,
  );

  Stream<geo.Position> positionStream() {
    if (kIsWeb) {
      return _webMockRouteProgressStream();
    }
    return geo.Geolocator.getPositionStream(
      locationSettings: _settings,
    );
  }

  /// Simulated movement along the active preview polyline (or a Cairo line).
  Stream<geo.Position> _webMockRouteProgressStream() {
    final c = WebPreviewState.activeRoutePolylineWgs ??
        CairoWebPreviewData.staticDemoRoute.coordinates;
    if (c.length < 2) {
      return Stream<geo.Position>.value(
        _mockPosition(
          c.isNotEmpty ? c[0] : <double>[31.2357, 30.0444],
        ),
      );
    }
    return _webRouteStream(c);
  }

  static Stream<geo.Position> _webRouteStream(List<List<double>> c) async* {
    var tick = 0;
    while (true) {
      WebPreviewState.streamTick = tick;
      final t = (tick % 200) / 200.0;
      final max = c.length - 1;
      final f = t * max;
      final i0 = f.floor();
      var i1 = i0 + 1;
      if (i1 > max) {
        i1 = max;
      }
      final tSeg = f - i0;
      final a = c[i0];
      final b = c[i1];
      final lng = a[0] + (b[0] - a[0]) * tSeg;
      final lat = a[1] + (b[1] - a[1]) * tSeg;
      yield _mockPosition(
        [lng, lat],
        heading: 38 + tick % 3,
      );
      tick++;
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
  }

  static geo.Position _mockPosition(
    List<double> lngLat, {
    double heading = 0,
  }) {
    return geo.Position(
      latitude: lngLat[1],
      longitude: lngLat[0],
      timestamp: DateTime.now(),
      accuracy: 12,
      altitude: 20,
      heading: heading,
      speed: 6.2,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
      speedAccuracy: 0,
    );
  }

  Future<geo.Position> currentPosition() {
    if (kIsWeb) {
      final c = WebPreviewState.activeRoutePolylineWgs ??
          CairoWebPreviewData.staticDemoRoute.coordinates;
      final p = c.isNotEmpty ? c.first : <double>[31.2357, 30.0444];
      return SynchronousFuture(_mockPosition(p));
    }
    return geo.Geolocator.getCurrentPosition(
      locationSettings: _settings,
    );
  }

  Future<geo.LocationPermission> requestPermission() async {
    if (kIsWeb) {
      return geo.LocationPermission.whileInUse;
    }
    var p = await geo.Geolocator.checkPermission();
    if (p == geo.LocationPermission.denied) {
      p = await geo.Geolocator.requestPermission();
    }
    return p;
  }

  Future<bool> isLocationServiceEnabled() {
    if (kIsWeb) {
      return SynchronousFuture(true);
    }
    return geo.Geolocator.isLocationServiceEnabled();
  }
}
