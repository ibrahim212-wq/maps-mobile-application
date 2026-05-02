class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.id,
    required this.name,
    required this.mapboxId,
    required this.lat,
    required this.lng,
    required this.selectionCount,
    required this.lastUsedAt,
  });

  final String id;
  final String name;
  final String mapboxId;
  final double lat;
  final double lng;
  final int selectionCount;
  final DateTime lastUsedAt;

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SearchHistoryEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      mapboxId: json['mapbox_id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      selectionCount: json['selection_count'] as int? ?? 1,
      lastUsedAt: DateTime.parse(json['last_used_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mapbox_id': mapboxId,
        'lat': lat,
        'lng': lng,
        'selection_count': selectionCount,
        'last_used_at': lastUsedAt.toIso8601String(),
      };

  SearchHistoryEntry copyWith({
    String? id,
    String? name,
    String? mapboxId,
    double? lat,
    double? lng,
    int? selectionCount,
    DateTime? lastUsedAt,
  }) {
    return SearchHistoryEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      mapboxId: mapboxId ?? this.mapboxId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      selectionCount: selectionCount ?? this.selectionCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}
