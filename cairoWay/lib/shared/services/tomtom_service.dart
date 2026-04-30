import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';

class TrafficFlowSample {
  final double currentSpeed;
  final double freeFlowSpeed;
  final double currentTravelTime;
  final double freeFlowTravelTime;
  final double confidence;
  final bool roadClosure;

  const TrafficFlowSample({
    required this.currentSpeed,
    required this.freeFlowSpeed,
    required this.currentTravelTime,
    required this.freeFlowTravelTime,
    required this.confidence,
    required this.roadClosure,
  });

  double get congestionRatio =>
      freeFlowSpeed == 0 ? 0 : (1 - (currentSpeed / freeFlowSpeed)).clamp(0, 1).toDouble();
}

/// TomTom Traffic Flow API — point-level real-time traffic.
class TomTomService {
  TomTomService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<TrafficFlowSample?> flowAt({
    required double lat,
    required double lng,
    int zoom = 12,
  }) async {
    final key = AppConstants.tomtomKey;
    if (key.isEmpty) return null;
    final uri = Uri.parse(
      'https://api.tomtom.com/traffic/services/4/flowSegmentData/absolute/$zoom/json',
    ).replace(queryParameters: {
      'point': '$lat,$lng',
      'unit': 'KMPH',
      'key': key,
    });
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['flowSegmentData'] as Map<String, dynamic>?;
      if (data == null) return null;
      return TrafficFlowSample(
        currentSpeed: ((data['currentSpeed'] as num?) ?? 0).toDouble(),
        freeFlowSpeed: ((data['freeFlowSpeed'] as num?) ?? 0).toDouble(),
        currentTravelTime:
            ((data['currentTravelTime'] as num?) ?? 0).toDouble(),
        freeFlowTravelTime:
            ((data['freeFlowTravelTime'] as num?) ?? 0).toDouble(),
        confidence: ((data['confidence'] as num?) ?? 0).toDouble(),
        roadClosure: (data['roadClosure'] as bool?) ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

final tomtomServiceProvider = Provider<TomTomService>((_) => TomTomService());
