import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/location_service.dart';
import '../../../../shared/services/osm_service.dart';

/// Toggle: traffic-signal layer visibility on the map.
final showTrafficSignalsProvider = StateProvider<bool>((_) => true);

/// Toggle: traffic congestion overlay (route style).
final showTrafficLayerProvider = StateProvider<bool>((_) => true);

/// Cached signal coordinates (lng,lat) keyed by bbox.
final trafficSignalsProvider =
    FutureProvider.family<List<List<double>>, Bbox>((ref, bbox) async {
  final svc = ref.read(osmServiceProvider);
  final signals = await svc.trafficSignals(
    south: bbox.south,
    west: bbox.west,
    north: bbox.north,
    east: bbox.east,
  );
  return signals.map((s) => [s.lng, s.lat]).toList();
});

@immutable
class Bbox {
  final double south, west, north, east;
  const Bbox(this.south, this.west, this.north, this.east);

  @override
  bool operator ==(Object other) =>
      other is Bbox &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);
}

/// Reactive current location (refreshable on pull / recenter tap).
final mapCurrentLocationProvider =
    FutureProvider<UserLocation?>((ref) async {
  return ref.read(locationServiceProvider).currentLocation();
});
