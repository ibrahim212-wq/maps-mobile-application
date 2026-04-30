import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../models/route_option.dart';

/// Mapbox Directions API — real driving routes with traffic.
class DirectionsService {
  DirectionsService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<RouteOption>> driveRoutes({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    bool alternatives = true,
    String profile = 'mapbox/driving-traffic',
  }) async {
    final token = AppConstants.mapboxToken;
    if (token.isEmpty) return [];
    final coords = '$fromLng,$fromLat;$toLng,$toLat';
    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/$profile/$coords',
    ).replace(queryParameters: {
      'access_token': token,
      'alternatives': '$alternatives',
      'geometries': 'geojson',
      'overview': 'full',
      'steps': 'true',
      'annotations': 'duration,distance,congestion',
      'language': 'en',
    });

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = (json['routes'] as List?) ?? const [];
      final result = <RouteOption>[];
      for (var i = 0; i < routes.length; i++) {
        final r = routes[i] as Map<String, dynamic>;
        final geom = (r['geometry'] as Map<String, dynamic>?)?['coordinates']
                as List? ??
            const [];
        final coordsList = geom
            .map((p) => (p as List).cast<num>().map((n) => n.toDouble()).toList())
            .toList();

        final legs = (r['legs'] as List?) ?? const [];
        final steps = <RouteStep>[];
        TrafficLevel level = TrafficLevel.free;

        for (final leg in legs) {
          final lm = leg as Map<String, dynamic>;
          // Aggregate congestion across leg
          final congestion = (lm['annotation']
                  as Map<String, dynamic>?)?['congestion'] as List?;
          if (congestion != null && congestion.isNotEmpty) {
            level = _worstLevel(level, _aggregateCongestion(congestion));
          }
          for (final s in (lm['steps'] as List? ?? const [])) {
            final sm = s as Map<String, dynamic>;
            final sgeom =
                (sm['geometry'] as Map<String, dynamic>?)?['coordinates']
                        as List? ??
                    const [];
            final maneuver = sm['maneuver'] as Map<String, dynamic>?;
            steps.add(RouteStep(
              instruction: (maneuver?['instruction'] as String?) ??
                  (sm['name'] as String? ?? ''),
              distanceMeters: ((sm['distance'] as num?) ?? 0).toDouble(),
              durationSeconds: ((sm['duration'] as num?) ?? 0).toDouble(),
              maneuverType: maneuver?['type'] as String?,
              maneuverModifier: maneuver?['modifier'] as String?,
              maneuverLocation: (maneuver?['location'] as List?)
                  ?.cast<num>()
                  .map((e) => e.toDouble())
                  .toList(),
              geometry: sgeom
                  .map((p) =>
                      (p as List).cast<num>().map((n) => n.toDouble()).toList())
                  .toList(),
            ));
          }
        }

        final duration = ((r['duration'] as num?) ?? 0).toDouble();
        final distance = ((r['distance'] as num?) ?? 0).toDouble();

        // Derive traffic from duration vs typical (use duration_typical if present)
        final typical = (r['duration_typical'] as num?)?.toDouble();
        if (typical != null && typical > 0) {
          final ratio = duration / typical;
          level = _worstLevel(level, _ratioToLevel(ratio));
        }

        result.add(RouteOption(
          id: 'r$i',
          summary: _buildSummary(legs, steps),
          distanceMeters: distance,
          durationSeconds: duration,
          durationInTrafficSeconds: duration,
          geometry: coordsList,
          steps: steps,
          trafficLevel: level,
        ));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Build a human-friendly route name like "via Salah Salem" by picking the
  /// longest-distance named segment from the route's steps. Falls back to the
  /// Mapbox leg summary, then to a generic label. Never exposes raw numbers.
  String _buildSummary(List legs, List<RouteStep> steps) {
    final namedSteps = steps
        .where((s) =>
            s.instruction.isNotEmpty &&
            s.distanceMeters > 100 &&
            _looksLikeRoadName(_extractName(s)))
        .toList()
      ..sort((a, b) => b.distanceMeters.compareTo(a.distanceMeters));
    if (namedSteps.isNotEmpty) {
      final name = _extractName(namedSteps.first);
      if (name.isNotEmpty) return 'via $name';
    }
    // Fall back to Mapbox leg-level summary if it looks like a road name.
    for (final leg in legs) {
      final s = ((leg as Map)['summary'] as String?)?.trim() ?? '';
      if (s.isNotEmpty && _looksLikeRoadName(s)) return 'via $s';
    }
    return 'Driving route';
  }

  String _extractName(RouteStep s) {
    // Prefer a clean name from the instruction by stripping verbs.
    final raw = s.instruction.trim();
    // Strip leading verbs like "Turn left onto X", "Merge onto X", "Continue on X".
    final lower = raw.toLowerCase();
    for (final marker in const [' onto ', ' on ', ' towards ', ' toward ']) {
      final i = lower.indexOf(marker);
      if (i > 0) {
        return raw.substring(i + marker.length).trim();
      }
    }
    return raw;
  }

  /// Reject names that look like raw numbers/IDs (e.g. "27,516") so we never
  /// surface junk in the UI.
  bool _looksLikeRoadName(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    // Reject if every character is a digit, comma, dot or space.
    final stripped = t.replaceAll(RegExp(r'[\d,.\s]'), '');
    return stripped.isNotEmpty;
  }

  TrafficLevel _aggregateCongestion(List congestion) {
    int score = 0;
    int count = 0;
    for (final c in congestion) {
      final s = c?.toString() ?? 'unknown';
      switch (s) {
        case 'low':
          score += 1;
          break;
        case 'moderate':
          score += 2;
          break;
        case 'heavy':
          score += 3;
          break;
        case 'severe':
          score += 4;
          break;
        default:
          continue;
      }
      count++;
    }
    if (count == 0) return TrafficLevel.free;
    final avg = score / count;
    if (avg < 1.2) return TrafficLevel.free;
    if (avg < 2.0) return TrafficLevel.light;
    if (avg < 2.8) return TrafficLevel.moderate;
    if (avg < 3.5) return TrafficLevel.heavy;
    return TrafficLevel.gridlock;
  }

  TrafficLevel _ratioToLevel(double r) {
    if (r < 1.1) return TrafficLevel.free;
    if (r < 1.3) return TrafficLevel.light;
    if (r < 1.6) return TrafficLevel.moderate;
    if (r < 2.0) return TrafficLevel.heavy;
    return TrafficLevel.gridlock;
  }

  TrafficLevel _worstLevel(TrafficLevel a, TrafficLevel b) =>
      a.index >= b.index ? a : b;
}

final directionsServiceProvider =
    Provider<DirectionsService>((_) => DirectionsService());
