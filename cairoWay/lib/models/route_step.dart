/// One turn-by-turn step from Mapbox Directions `steps[]`.
class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.maneuverType,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverLng,
    required this.maneuverLat,
    this.streetName,
  });

  /// Human-readable instruction (e.g. "Turn right onto X").
  final String instruction;

  /// `maneuver.type` (e.g. `turn`, `arrive`, `depart`, `roundabout`).
  final String maneuverType;

  final double distanceMeters;
  final double durationSeconds;

  /// Coordinates of the maneuver point (where the action occurs).
  final double maneuverLng;
  final double maneuverLat;
  final String? streetName;
}
