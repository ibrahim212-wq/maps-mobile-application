import '../models/navigation_route.dart';
import '../models/route_step.dart';

/// Sample Cairo traffic / route data for `kIsWeb` development preview only.
/// Not used in production Android/iOS builds.
class CairoWebPreviewData {
  CairoWebPreviewData._();

  /// Heliopolis demo (matches home nav FAB) — [lng, lat] polyline, simplified.
  static const double demoDestinationLat = 30.0886;
  static const double demoDestinationLng = 31.3244;

  static final List<String> trafficHeadlines = [
    '6th Oct Bridge — moderate (mock)',
    'Salah Salem — free flow',
    'Ring Road (east) — heavy near junction (mock)',
  ];

  static final List<List<double>> _tahrirToHeliopolis = _buildCruiseLine();

  static List<List<double>> _buildCruiseLine() {
    const start = [31.2357, 30.0444];
    const end = [31.3244, 30.0886];
    const n = 30;
    final out = <List<double>>[];
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      out.add([
        start[0] + (end[0] - start[0]) * t,
        start[1] + (end[1] - start[1]) * t,
      ]);
    }
    return out;
  }

  static List<RouteStep> get _sampleSteps => [
        const RouteStep(
          instruction: 'Head northeast on Talaat Harb (mock preview)',
          maneuverType: 'depart',
          distanceMeters: 420,
          durationSeconds: 90,
          maneuverLng: 31.25,
          maneuverLat: 30.05,
          streetName: 'Downtown',
        ),
        const RouteStep(
          instruction: 'Keep right onto Salah Salem (mock — typical Cairo commute)',
          maneuverType: 'turn',
          distanceMeters: 5800,
          durationSeconds: 700,
          maneuverLng: 31.30,
          maneuverLat: 30.07,
          streetName: 'Salah Salem',
        ),
        const RouteStep(
          instruction: 'Arrive at destination in Heliopolis (preview)',
          maneuverType: 'arrive',
          distanceMeters: 1200,
          durationSeconds: 180,
          maneuverLng: demoDestinationLng,
          maneuverLat: demoDestinationLat,
          streetName: 'Heliopolis',
        ),
      ];

  static NavigationRoute navigationRouteToDemo({
    required double originLat,
    required double originLng,
  }) {
    var coords = List<List<double>>.from(_tahrirToHeliopolis);
    if (coords.isNotEmpty) {
      coords[0] = [originLng, originLat];
    }
    return NavigationRoute(
      coordinates: coords,
      steps: _sampleSteps,
      totalDurationSeconds: 1100,
      totalDistanceMeters: 11500,
      destinationLng: demoDestinationLng,
      destinationLat: demoDestinationLat,
    );
  }

  static NavigationRoute get staticDemoRoute => navigationRouteToDemo(
        originLat: 30.0444,
        originLng: 31.2357,
      );
}
