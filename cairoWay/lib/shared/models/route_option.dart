import 'package:flutter/foundation.dart';

enum TrafficLevel { free, light, moderate, heavy, gridlock }

@immutable
class RouteStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final List<List<double>> geometry; // [lng,lat]
  final String? maneuverType;
  final String? maneuverModifier;
  final List<double>? maneuverLocation;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.geometry,
    this.maneuverType,
    this.maneuverModifier,
    this.maneuverLocation,
  });
}

@immutable
class RouteOption {
  final String id;
  final String summary;
  final double distanceMeters;
  final double durationSeconds;
  final double? durationInTrafficSeconds;
  final List<List<double>> geometry; // list of [lng,lat]
  final List<RouteStep> steps;
  final TrafficLevel trafficLevel;
  final bool aiPick;
  final String? aiReason;

  const RouteOption({
    required this.id,
    required this.summary,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.geometry,
    required this.steps,
    required this.trafficLevel,
    this.durationInTrafficSeconds,
    this.aiPick = false,
    this.aiReason,
  });

  RouteOption copyWith({bool? aiPick, String? aiReason, TrafficLevel? trafficLevel}) {
    return RouteOption(
      id: id,
      summary: summary,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      durationInTrafficSeconds: durationInTrafficSeconds,
      geometry: geometry,
      steps: steps,
      trafficLevel: trafficLevel ?? this.trafficLevel,
      aiPick: aiPick ?? this.aiPick,
      aiReason: aiReason ?? this.aiReason,
    );
  }
}
