import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class TrafficSignal {
  final double lat;
  final double lng;
  final int id;
  const TrafficSignal({required this.id, required this.lat, required this.lng});
}

/// OpenStreetMap Overpass API — fetches traffic signals in a bbox.
class OsmService {
  OsmService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  Future<List<TrafficSignal>> trafficSignals({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final query =
        '[out:json][timeout:15];node["highway"="traffic_signals"]($south,$west,$north,$east);out body;';
    try {
      final res = await _client
          .post(Uri.parse(_endpoint), body: {'data': query})
          .timeout(const Duration(seconds: 18));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final elements = (json['elements'] as List?) ?? const [];
      return elements
          .whereType<Map>()
          .where((e) => e['type'] == 'node')
          .map((e) => TrafficSignal(
                id: (e['id'] as num).toInt(),
                lat: (e['lat'] as num).toDouble(),
                lng: (e['lon'] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final osmServiceProvider = Provider<OsmService>((_) => OsmService());
