import 'package:flutter/foundation.dart';

enum IncidentType { accident, heavyTraffic, roadClosed, police, construction, hazard }

extension IncidentTypeX on IncidentType {
  String get label => switch (this) {
        IncidentType.accident => 'Accident',
        IncidentType.heavyTraffic => 'Heavy Traffic',
        IncidentType.roadClosed => 'Road Closed',
        IncidentType.police => 'Police',
        IncidentType.construction => 'Construction',
        IncidentType.hazard => 'Hazard',
      };

  String get emoji => switch (this) {
        IncidentType.accident => '🚧',
        IncidentType.heavyTraffic => '🚗',
        IncidentType.roadClosed => '🚫',
        IncidentType.police => '🚔',
        IncidentType.construction => '🏗️',
        IncidentType.hazard => '⚠️',
      };
}

@immutable
class Incident {
  final String id;
  final IncidentType type;
  final double lat;
  final double lng;
  final String? note;
  final DateTime reportedAt;

  const Incident({
    required this.id,
    required this.type,
    required this.lat,
    required this.lng,
    required this.reportedAt,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'lat': lat,
        'lng': lng,
        'note': note,
        'reportedAt': reportedAt.toIso8601String(),
      };

  factory Incident.fromJson(Map<dynamic, dynamic> j) => Incident(
        id: j['id'] as String,
        type: IncidentType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => IncidentType.hazard,
        ),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        note: j['note'] as String?,
        reportedAt: DateTime.parse(j['reportedAt'] as String),
      );
}
