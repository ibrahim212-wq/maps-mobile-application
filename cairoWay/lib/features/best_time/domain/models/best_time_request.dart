import 'package:flutter/foundation.dart';

/// Strongly-typed payload for `POST /api/v1/best-time`.
///
/// Equality is implemented so this can be used as a Riverpod `family` key
/// and the same parameters won't trigger duplicate fetches.
@immutable
class BestTimeRequest {
  const BestTimeRequest({
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.arrivalTime,
    this.searchWindowMinutes = 60,
    this.intervalMinutes = 15,
    this.mapboxRouteJunctions = const <String>[],
  });

  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final DateTime arrivalTime;
  final int searchWindowMinutes;
  final int intervalMinutes;
  final List<String> mapboxRouteJunctions;

  Map<String, dynamic> toJson() => {
        'from_lat': fromLat,
        'from_lng': fromLng,
        'to_lat': toLat,
        'to_lng': toLng,
        'arrival_time': arrivalTime.toUtc().toIso8601String(),
        'search_window_minutes': searchWindowMinutes,
        'interval_minutes': intervalMinutes,
        'mapbox_route_junctions': mapboxRouteJunctions,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BestTimeRequest &&
        other.fromLat == fromLat &&
        other.fromLng == fromLng &&
        other.toLat == toLat &&
        other.toLng == toLng &&
        other.arrivalTime == arrivalTime &&
        other.searchWindowMinutes == searchWindowMinutes &&
        other.intervalMinutes == intervalMinutes &&
        listEquals(other.mapboxRouteJunctions, mapboxRouteJunctions);
  }

  @override
  int get hashCode => Object.hash(
        fromLat,
        fromLng,
        toLat,
        toLng,
        arrivalTime,
        searchWindowMinutes,
        intervalMinutes,
        Object.hashAll(mapboxRouteJunctions),
      );
}
