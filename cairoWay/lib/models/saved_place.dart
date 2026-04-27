/// Home / Work (or any labeled favorite) from onboarding.
class SavedPlace {
  const SavedPlace({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
        'label': label,
        'lat': latitude,
        'lng': longitude,
      };

  static SavedPlace? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return SavedPlace(
      label: (json['label'] as String?)?.trim() ?? 'Saved',
      latitude: lat,
      longitude: lng,
    );
  }
}
