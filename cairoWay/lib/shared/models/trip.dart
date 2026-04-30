import 'package:flutter/foundation.dart';

/// State machine for an in-progress / completed trip.
enum TripStatus {
  /// Currently navigating.
  active,

  /// Reached within ~50m of the destination.
  arrived,

  /// Cancelled in the first 5 minutes AND within first 10% of route.
  cancelledNearStart,

  /// Cancelled mid-route (after 5 min OR > 10% covered).
  cancelledMidway,

  /// Paused (could resume).
  paused,
}

@immutable
class Trip {
  final String id;
  final String fromName;
  final String toName;
  final double durationSeconds;
  final double distanceMeters;

  /// How much of the planned route the user actually covered, in meters.
  /// Equal to [distanceMeters] for arrived trips.
  final double? distanceCoveredMeters;
  final double? predictedSeconds;
  final DateTime startedAt;
  final DateTime? endedAt;
  final TripStatus status;

  const Trip({
    required this.id,
    required this.fromName,
    required this.toName,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.startedAt,
    this.distanceCoveredMeters,
    this.predictedSeconds,
    this.endedAt,
    this.status = TripStatus.arrived,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromName': fromName,
        'toName': toName,
        'durationSeconds': durationSeconds,
        'distanceMeters': distanceMeters,
        'distanceCoveredMeters': distanceCoveredMeters,
        'predictedSeconds': predictedSeconds,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'status': status.name,
      };

  factory Trip.fromJson(Map<dynamic, dynamic> j) => Trip(
        id: j['id'] as String,
        fromName: j['fromName'] as String,
        toName: j['toName'] as String,
        durationSeconds: (j['durationSeconds'] as num).toDouble(),
        distanceMeters: (j['distanceMeters'] as num).toDouble(),
        distanceCoveredMeters:
            (j['distanceCoveredMeters'] as num?)?.toDouble(),
        predictedSeconds: (j['predictedSeconds'] as num?)?.toDouble(),
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: j['endedAt'] != null
            ? DateTime.parse(j['endedAt'] as String)
            : null,
        status: TripStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => TripStatus.arrived,
        ),
      );
}
