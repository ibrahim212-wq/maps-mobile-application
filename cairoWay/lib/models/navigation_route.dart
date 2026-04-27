import 'dart:convert';

import 'route_step.dart';

/// Parsed driving route from Mapbox Directions API.
class NavigationRoute {
  const NavigationRoute({
    required this.coordinates,
    required this.steps,
    required this.totalDurationSeconds,
    required this.totalDistanceMeters,
    required this.destinationLng,
    required this.destinationLat,
  });

  /// LineString as `[lng, lat]` points (WGS84).
  final List<List<double>> coordinates;
  final List<RouteStep> steps;
  final double totalDurationSeconds;
  final double totalDistanceMeters;
  final double destinationLng;
  final double destinationLat;

  /// Full route GeoJSON for a `LineString` `source`.
  String toFullRouteGeoJson() {
    return _lineStringToGeoJson(coordinates);
  }

  /// Sub-path from [startIndex] to the end of [coordinates] (remaining polyline).
  String toRemainingGeoJsonFromIndex(int startIndex) {
    if (coordinates.isEmpty) return toFullRouteGeoJson();
    final i = startIndex.clamp(0, coordinates.length - 1);
    final sub = coordinates.sublist(i);
    if (sub.length < 2) {
      return _lineStringToGeoJson(<List<double>>[sub.first, sub.first]);
    }
    return _lineStringToGeoJson(sub);
  }

  static String _lineStringToGeoJson(List<List<double>> coords) {
    return json.encode(<String, Object?>{
      'type': 'Feature',
      'properties': <String, Object?>{},
      'geometry': <String, Object?>{
        'type': 'LineString',
        'coordinates': coords,
      },
    });
  }
}
