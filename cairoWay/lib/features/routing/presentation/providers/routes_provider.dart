import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/place.dart';
import '../../../../shared/models/route_option.dart';
import '../../../../shared/services/directions_service.dart';

@immutable
class RouteQuery {
  final double fromLat, fromLng, toLat, toLng;
  const RouteQuery(this.fromLat, this.fromLng, this.toLat, this.toLng);

  @override
  bool operator ==(Object other) =>
      other is RouteQuery &&
      other.fromLat == fromLat &&
      other.fromLng == fromLng &&
      other.toLat == toLat &&
      other.toLng == toLng;

  @override
  int get hashCode => Object.hash(fromLat, fromLng, toLat, toLng);
}

final routesProvider =
    FutureProvider.family<List<RouteOption>, RouteQuery>((ref, q) async {
  final svc = ref.read(directionsServiceProvider);
  final routes = await svc.driveRoutes(
    fromLat: q.fromLat,
    fromLng: q.fromLng,
    toLat: q.toLat,
    toLng: q.toLng,
  );
  if (routes.isEmpty) return routes;
  // Local "best pick" heuristic until the AI backend is available:
  //   primary: shortest live-traffic duration
  //   tiebreak: lowest traffic level, then shortest distance
  final ranked = [...routes]..sort((a, b) {
      final byDur = a.durationSeconds.compareTo(b.durationSeconds);
      if (byDur != 0) return byDur;
      final byTraffic = a.trafficLevel.index.compareTo(b.trafficLevel.index);
      if (byTraffic != 0) return byTraffic;
      return a.distanceMeters.compareTo(b.distanceMeters);
    });
  final pick = ranked.first;
  // How much faster the pick is vs the slowest alternative.
  final slowest = ranked.last.durationSeconds;
  final saved = (slowest - pick.durationSeconds).clamp(0, double.infinity);
  final reason = saved > 60
      ? 'Saves ~${(saved / 60).round()} min vs slower alternatives'
      : 'Fastest route based on live traffic';
  return routes
      .map((r) => r.id == pick.id
          ? r.copyWith(aiPick: true, aiReason: reason)
          : r)
      .toList();
});

@immutable
class OriginDestination {
  final Place? origin;
  final Place destination;
  const OriginDestination({this.origin, required this.destination});
}
