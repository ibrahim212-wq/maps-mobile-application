import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches traffic signal locations from OpenStreetMap via the public Overpass API.
/// Bbox is (south, west, north, east) in degrees.
class OsmTrafficSignalsService {
  OsmTrafficSignalsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';

  /// Returns point coordinates [lng, lat] for [highway=traffic_signals] in the bbox.
  Future<List<({double lat, double lng})>> fetchTrafficSignalsInBbox({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final q = '''
[out:json][timeout:25];
(
  node["highway"="traffic_signals"]($south,$west,$north,$east);
  way["highway"="traffic_signals"]($south,$west,$north,$east);
);
out center;
''';
    final res = await _client
        .post(
      Uri.parse(_overpassUrl),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'data=${Uri.encodeQueryComponent(q)}',
    )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      return [];
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>?;
    if (elements == null) return [];
    final out = <({double lat, double lng})>[];
    for (final e in elements) {
      final m = e as Map<String, dynamic>;
      if (m['type'] == 'node') {
        final lat = m['lat'] as num?;
        final lon = m['lon'] as num?;
        if (lat != null && lon != null) {
          out.add((lat: lat.toDouble(), lng: lon.toDouble()));
        }
      } else if (m['type'] == 'way') {
        final c = m['center'] as Map<String, dynamic>?;
        if (c != null) {
          final lat = c['lat'] as num?;
          final lon = c['lon'] as num?;
          if (lat != null && lon != null) {
            out.add((lat: lat.toDouble(), lng: lon.toDouble()));
          }
        }
      }
    }
    return out;
  }

  /// Default bbox around greater central Cairo (approx.).
  static ({double south, double west, double north, double east})
      defaultCairoBbox() {
    return (
      south: 29.95,
      west: 31.05,
      north: 30.15,
      east: 31.45,
    );
  }
}

String trafficSignalsToGeoJson(List<({double lat, double lng})> points) {
  final features = [
    for (var i = 0; i < points.length; i++)
      {
        'type': 'Feature',
        'id': i,
        'properties': <String, dynamic>{},
        'geometry': {
          'type': 'Point',
          'coordinates': <double>[points[i].lng, points[i].lat],
        },
      }
  ];
  return jsonEncode({
    'type': 'FeatureCollection',
    'features': features,
  });
}
