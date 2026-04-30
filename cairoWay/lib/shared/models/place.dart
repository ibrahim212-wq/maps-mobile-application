import 'package:flutter/foundation.dart';

@immutable
class Place {
  final String id;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final String? category;

  const Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.address,
    this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'category': category,
      };

  factory Place.fromJson(Map<dynamic, dynamic> j) => Place(
        id: j['id'] as String,
        name: j['name'] as String,
        address: j['address'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        category: j['category'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Place && other.id == id && other.lat == lat && other.lng == lng);

  @override
  int get hashCode => Object.hash(id, lat, lng);
}

@immutable
class SavedPlace {
  final String id;
  final String label; // 'home', 'work', or custom
  final Place place;

  const SavedPlace({required this.id, required this.label, required this.place});

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'place': place.toJson(),
      };

  factory SavedPlace.fromJson(Map<dynamic, dynamic> j) => SavedPlace(
        id: j['id'] as String,
        label: j['label'] as String,
        place: Place.fromJson(Map<String, dynamic>.from(j['place'] as Map)),
      );
}
