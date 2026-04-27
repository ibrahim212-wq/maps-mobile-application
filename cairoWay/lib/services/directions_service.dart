import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../core/platform/web_preview_state.dart';
import '../data/cairo_web_preview_data.dart';
import '../models/navigation_route.dart';
import '../models/route_step.dart';

/// Mapbox Directions API (driving) over HTTPS — uses public access token in query.
class DirectionsService {
  DirectionsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://api.mapbox.com/directions/v5/mapbox/driving';

  /// Fetches a driving route with `geometries=geojson`, `steps=true`, `overview=full`.
  Future<NavigationRoute> fetchRoute({
    required String accessToken,
    required double originLng,
    required double originLat,
    required double destinationLng,
    required double destinationLat,
  }) async {
    if (kIsWeb) {
      final r = CairoWebPreviewData.navigationRouteToDemo(
        originLat: originLat,
        originLng: originLng,
      );
      WebPreviewState.setActivePolyline(r.coordinates);
      return r;
    }
    if (accessToken.isEmpty) {
      throw const DirectionsException('Mapbox access token is missing.');
    }
    // Mapbox: `coordinates` = {lng,lat} pairs separated by `;`
    final path =
        '$originLng,$originLat;$destinationLng,$destinationLat';
    final query = <String, String>{
      'geometries': 'geojson',
      'steps': 'true',
      'overview': 'full',
      'access_token': accessToken,
    };
    final uri = Uri.parse('$_base/$path').replace(queryParameters: query);
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      String detail = res.body;
      if (detail.length > 200) {
        detail = '${detail.substring(0, 200)}…';
      }
      throw DirectionsException(
        'Directions request failed (${res.statusCode}). $detail',
      );
    }
    return _parseDirectionsResponse(
      res.body,
      destinationLng: destinationLng,
      destinationLat: destinationLat,
    );
  }

  /// Parses JSON and builds [NavigationRoute]; throws on invalid shape.
  NavigationRoute _parseDirectionsResponse(
    String body, {
    required double destinationLng,
    required double destinationLat,
  }) {
    final map = json.decode(body) as Map<String, dynamic>;
    final code = map['code'] as String?;
    if (code != 'Ok' && code != 'ok') {
      final msg = map['message'] as String? ?? 'No route found.';
      throw DirectionsException(msg);
    }
    final routes = map['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw const DirectionsException('No routes in response.');
    }
    final r0 = routes.first as Map<String, dynamic>;
    final duration = (r0['duration'] as num).toDouble();
    final distance = (r0['distance'] as num).toDouble();
    final geometry = r0['geometry'] as Map<String, dynamic>?;
    if (geometry == null) {
      throw const DirectionsException('Route has no geometry.');
    }
    final rawCoords = geometry['coordinates'] as List<dynamic>?;
    if (rawCoords == null || rawCoords.isEmpty) {
      throw const DirectionsException('Route geometry is empty.');
    }
    final coordinates = <List<double>>[];
    for (final p in rawCoords) {
      final pair = p as List<dynamic>;
      coordinates.add(<double>[
        (pair[0] as num).toDouble(),
        (pair[1] as num).toDouble(),
      ]);
    }
    final legs = r0['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) {
      throw const DirectionsException('Route has no legs.');
    }
    final leg0 = legs.first as Map<String, dynamic>;
    final stepsJson = leg0['steps'] as List<dynamic>? ?? <dynamic>[];
    final steps = <RouteStep>[];
    for (final s in stepsJson) {
      final m = s as Map<String, dynamic>;
      final maneuver = m['maneuver'] as Map<String, dynamic>?;
      final type = (maneuver?['type'] as String?)?.trim() ?? 'unknown';
      var instruction = (maneuver?['instruction'] as String?)?.trim() ?? '';
      if (instruction.isEmpty) {
        instruction = _fallbackInstruction(type, m['name'] as String?);
      }
      final loc = maneuver?['location'] as List<dynamic>?;
      double mLng, mLat;
      if (loc != null && loc.length >= 2) {
        mLng = (loc[0] as num).toDouble();
        mLat = (loc[1] as num).toDouble();
      } else {
        mLng = destinationLng;
        mLat = destinationLat;
      }
      steps.add(
        RouteStep(
          instruction: instruction,
          maneuverType: type,
          distanceMeters: (m['distance'] as num?)?.toDouble() ?? 0,
          durationSeconds: (m['duration'] as num?)?.toDouble() ?? 0,
          maneuverLng: mLng,
          maneuverLat: mLat,
          streetName: m['name'] as String?,
        ),
      );
    }
    if (steps.isEmpty) {
      throw const DirectionsException('Route has no steps.');
    }
    return NavigationRoute(
      coordinates: coordinates,
      steps: steps,
      totalDurationSeconds: duration,
      totalDistanceMeters: distance,
      destinationLng: destinationLng,
      destinationLat: destinationLat,
    );
  }

  static String _fallbackInstruction(String type, String? name) {
    final n = (name ?? '').trim();
    if (n.isNotEmpty) {
      return 'Continue on $n';
    }
    switch (type) {
      case 'arrive':
        return 'Arrive at destination';
      case 'depart':
        return 'Start route';
      default:
        return 'Continue';
    }
  }
}

class DirectionsException implements Exception {
  const DirectionsException(this.message);
  final String message;

  @override
  String toString() => 'DirectionsException: $message';
}
