import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../models/incident.dart';
import '../models/place.dart';
import '../models/trip.dart';

/// Hive-backed persistent storage for recents, saved places, incidents, settings.
class StorageService {
  StorageService._(this._cache, this._recents, this._saved, this._incidents,
      this._settings, this._trips);

  final Box<dynamic> _cache;
  final Box<dynamic> _recents;
  final Box<dynamic> _saved;
  final Box<dynamic> _incidents;
  final Box<dynamic> _settings;
  final Box<dynamic> _trips;

  static const _uuid = Uuid();

  static Future<StorageService> init() async {
    await Hive.initFlutter();
    final cache = await Hive.openBox<dynamic>(AppConstants.boxCache);
    final recents = await Hive.openBox<dynamic>(AppConstants.boxRecents);
    final saved = await Hive.openBox<dynamic>(AppConstants.boxSavedPlaces);
    final incidents = await Hive.openBox<dynamic>(AppConstants.boxIncidents);
    final settings = await Hive.openBox<dynamic>(AppConstants.boxSettings);
    final trips = await Hive.openBox<dynamic>(AppConstants.boxTrips);
    return StorageService._(cache, recents, saved, incidents, settings, trips);
  }

  // ─── Settings ───
  T? getSetting<T>(String key) => _settings.get(key) as T?;
  Future<void> setSetting<T>(String key, T value) =>
      _settings.put(key, value);

  // ─── Recents ───
  List<Place> recents() {
    return _recents.values
        .whereType<Map>()
        .map((e) => Place.fromJson(e))
        .toList();
  }

  Future<void> addRecent(Place place) async {
    final list = recents().where((p) => p.id != place.id).toList();
    list.insert(0, place);
    final trimmed = list.take(15).toList();
    await _recents.clear();
    for (final p in trimmed) {
      await _recents.add(p.toJson());
    }
  }

  Future<void> clearRecents() => _recents.clear();

  // ─── Saved places ───
  List<SavedPlace> savedPlaces() {
    return _saved.values
        .whereType<Map>()
        .map((e) => SavedPlace.fromJson(e))
        .toList();
  }

  SavedPlace? savedByLabel(String label) {
    for (final v in _saved.values) {
      if (v is Map && v['label'] == label) return SavedPlace.fromJson(v);
    }
    return null;
  }

  Future<void> upsertSavedPlace(String label, Place place) async {
    // Remove existing with same label
    final keysToRemove = <dynamic>[];
    for (final entry in _saved.toMap().entries) {
      final v = entry.value;
      if (v is Map && v['label'] == label) keysToRemove.add(entry.key);
    }
    for (final k in keysToRemove) {
      await _saved.delete(k);
    }
    final saved = SavedPlace(id: _uuid.v4(), label: label, place: place);
    await _saved.put(saved.id, saved.toJson());
  }

  Future<void> removeSavedPlace(String id) => _saved.delete(id);

  // ─── Incidents ───
  List<Incident> incidents() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 2));
    return _incidents.values
        .whereType<Map>()
        .map((e) => Incident.fromJson(e))
        .where((i) => i.reportedAt.isAfter(cutoff))
        .toList();
  }

  Future<Incident> addIncident({
    required IncidentType type,
    required double lat,
    required double lng,
    String? note,
  }) async {
    final inc = Incident(
      id: _uuid.v4(),
      type: type,
      lat: lat,
      lng: lng,
      note: note,
      reportedAt: DateTime.now(),
    );
    await _incidents.put(inc.id, inc.toJson());
    return inc;
  }

  // ─── Trips ───
  List<Trip> trips() => _trips.values
      .whereType<Map>()
      .map((e) => Trip.fromJson(e))
      .toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  Future<void> addTrip(Trip trip) => _trips.put(trip.id, trip.toJson());

  // ─── Generic cache (for routes, traffic snapshots) ───
  Future<void> cachePut(String key, dynamic value) => _cache.put(key, value);
  T? cacheGet<T>(String key) => _cache.get(key) as T?;
}

final storageServiceProvider = Provider<StorageService>((_) {
  throw UnimplementedError('Override in main()');
});
