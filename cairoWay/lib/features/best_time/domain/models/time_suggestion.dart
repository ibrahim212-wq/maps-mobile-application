import 'package:flutter/material.dart';

/// Traffic congestion level. Mirrors the backend enum and the categories
/// used elsewhere in the app for consistent color coding.
enum TrafficLevel { free, light, moderate, heavy, gridlock }

extension TrafficLevelX on TrafficLevel {
  /// Color used in Best Time UI. Matches the spec from the product brief.
  Color get color {
    switch (this) {
      case TrafficLevel.free:
        return const Color(0xFF00C853);
      case TrafficLevel.light:
        return const Color(0xFF69F0AE);
      case TrafficLevel.moderate:
        return const Color(0xFFFFD740);
      case TrafficLevel.heavy:
        return const Color(0xFFFF6D00);
      case TrafficLevel.gridlock:
        return const Color(0xFFF44336);
    }
  }

  String get label {
    switch (this) {
      case TrafficLevel.free:
        return 'Free flow';
      case TrafficLevel.light:
        return 'Light';
      case TrafficLevel.moderate:
        return 'Moderate';
      case TrafficLevel.heavy:
        return 'Heavy';
      case TrafficLevel.gridlock:
        return 'Gridlock';
    }
  }

  IconData get icon {
    switch (this) {
      case TrafficLevel.free:
        return Icons.check_circle_rounded;
      case TrafficLevel.light:
        return Icons.trending_flat_rounded;
      case TrafficLevel.moderate:
        return Icons.show_chart_rounded;
      case TrafficLevel.heavy:
        return Icons.warning_amber_rounded;
      case TrafficLevel.gridlock:
        return Icons.error_rounded;
    }
  }

  /// Maps the backend string contract (FREE/LIGHT/MODERATE/HEAVY/GRIDLOCK)
  /// to the enum, falling back to moderate for unknown values.
  static TrafficLevel fromApi(String raw) {
    switch (raw.toUpperCase()) {
      case 'FREE':
        return TrafficLevel.free;
      case 'LIGHT':
        return TrafficLevel.light;
      case 'MODERATE':
        return TrafficLevel.moderate;
      case 'HEAVY':
        return TrafficLevel.heavy;
      case 'GRIDLOCK':
        return TrafficLevel.gridlock;
      default:
        return TrafficLevel.moderate;
    }
  }
}

/// One predicted departure option from the AI Best-Time pipeline.
@immutable
class TimeSuggestion {
  const TimeSuggestion({
    required this.departureTime,
    required this.estimatedDurationMinutes,
    required this.arrivalTime,
    required this.trafficLevel,
    required this.confidenceScore,
    required this.isRecommended,
    required this.reasoning,
  });

  final DateTime departureTime;
  final int estimatedDurationMinutes;
  final DateTime arrivalTime;
  final TrafficLevel trafficLevel;

  /// 0..1 — how confident the AI is in this prediction.
  final double confidenceScore;
  final bool isRecommended;
  final String reasoning;

  TimeSuggestion copyWith({bool? isRecommended}) => TimeSuggestion(
        departureTime: departureTime,
        estimatedDurationMinutes: estimatedDurationMinutes,
        arrivalTime: arrivalTime,
        trafficLevel: trafficLevel,
        confidenceScore: confidenceScore,
        isRecommended: isRecommended ?? this.isRecommended,
        reasoning: reasoning,
      );

  factory TimeSuggestion.fromJson(Map<String, dynamic> json) => TimeSuggestion(
        departureTime: DateTime.parse(json['departure_time'] as String),
        estimatedDurationMinutes:
            (json['estimated_duration_minutes'] as num).toInt(),
        arrivalTime: DateTime.parse(json['arrival_time'] as String),
        trafficLevel:
            TrafficLevelX.fromApi(json['traffic_level'] as String? ?? ''),
        confidenceScore: (json['confidence_score'] as num).toDouble(),
        isRecommended: json['is_recommended'] as bool? ?? false,
        reasoning: json['reasoning'] as String? ?? '',
      );
}

/// Top-level response wrapping a list of [TimeSuggestion]s plus metadata
/// about route distance and AI readiness.
@immutable
class BestTimeResult {
  const BestTimeResult({
    required this.routeDistanceKm,
    required this.junctionsAnalyzed,
    required this.suggestions,
    required this.aiStatus,
  });

  final double routeDistanceKm;
  final int junctionsAnalyzed;
  final List<TimeSuggestion> suggestions;

  /// "ready" once the AI has historical patterns; "initializing" otherwise.
  final String aiStatus;

  bool get isReady => aiStatus.toLowerCase() == 'ready';

  TimeSuggestion? get recommended {
    for (final s in suggestions) {
      if (s.isRecommended) return s;
    }
    return suggestions.isEmpty ? null : suggestions.first;
  }

  factory BestTimeResult.fromJson(Map<String, dynamic> json) => BestTimeResult(
        routeDistanceKm: (json['route_distance_km'] as num).toDouble(),
        junctionsAnalyzed: (json['junctions_analyzed'] as num).toInt(),
        suggestions: (json['suggestions'] as List<dynamic>? ?? const [])
            .map((e) => TimeSuggestion.fromJson(e as Map<String, dynamic>))
            .toList(),
        aiStatus: json['ai_status'] as String? ?? 'initializing',
      );
}
