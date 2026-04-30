import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../shared/models/route_option.dart';

/// State for any AI-powered call.
sealed class AiResult<T> {
  const AiResult();
}

class AiInitializing<T> extends AiResult<T> {
  const AiInitializing();
}

class AiSuccess<T> extends AiResult<T> {
  final T data;
  const AiSuccess(this.data);
}

class AiUnavailable<T> extends AiResult<T> {
  final String reason;
  const AiUnavailable(this.reason);
}

class BestTimeSuggestion {
  final DateTime departAt;
  final double durationSeconds;
  final TrafficLevel level;
  final String? note;
  const BestTimeSuggestion({
    required this.departAt,
    required this.durationSeconds,
    required this.level,
    this.note,
  });
}

class WeeklyInsights {
  final int totalTrips;
  final double timeSavedSeconds;
  final double aiAccuracy;
  final String? worstDay;
  final String? bestDay;
  final String? tip;
  const WeeklyInsights({
    required this.totalTrips,
    required this.timeSavedSeconds,
    required this.aiAccuracy,
    this.worstDay,
    this.bestDay,
    this.tip,
  });
}

/// AiService talks to the (not-yet-deployed) RouteMind backend.
/// Endpoint structure mirrors the PRD §6 so we can plug-and-play later.
class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  String get _base => AppConstants.aiBaseUrl;

  Future<bool> health() async {
    try {
      final res = await _client
          .get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AiResult<List<BestTimeSuggestion>>> bestTime({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    DateTime? earliest,
    DateTime? latest,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse('$_base/best-time'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'from': {'lat': fromLat, 'lng': fromLng},
          'to': {'lat': toLat, 'lng': toLng},
          if (earliest != null) 'earliest': earliest.toIso8601String(),
          if (latest != null) 'latest': latest.toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        return const AiUnavailable('AI service initializing…');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (json['suggestions'] as List? ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .map((e) => BestTimeSuggestion(
                departAt: DateTime.parse(e['time'] as String),
                durationSeconds: (e['duration'] as num).toDouble(),
                level: _levelFrom(e['traffic_level'] as String?),
                note: e['note'] as String?,
              ))
          .toList();
      return AiSuccess(list);
    } catch (_) {
      return const AiUnavailable('AI service initializing…');
    }
  }

  Future<AiResult<List<RouteOption>>> aiRoutes({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    DateTime? departureTime,
  }) async {
    // Backend not yet built — surface a clear initializing state.
    if (!await health()) {
      return const AiUnavailable('AI service initializing…');
    }
    return const AiUnavailable('AI service initializing…');
  }

  Future<AiResult<WeeklyInsights>> weeklyInsights() async {
    if (!await health()) {
      return const AiUnavailable('Connect to AI service for insights');
    }
    return const AiUnavailable('Connect to AI service for insights');
  }

  TrafficLevel _levelFrom(String? s) => switch (s) {
        'FREE' => TrafficLevel.free,
        'LIGHT' => TrafficLevel.light,
        'MODERATE' => TrafficLevel.moderate,
        'HEAVY' => TrafficLevel.heavy,
        'GRIDLOCK' => TrafficLevel.gridlock,
        _ => TrafficLevel.free,
      };
}

final aiServiceProvider = Provider<AiService>((_) => AiService());
