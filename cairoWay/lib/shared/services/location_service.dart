import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';

class UserLocation {
  final double lat;
  final double lng;
  final double? heading;
  final double? speed;
  final DateTime timestamp;

  const UserLocation({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.heading,
    this.speed,
  });

  factory UserLocation.fromPosition(Position p) => UserLocation(
        lat: p.latitude,
        lng: p.longitude,
        heading: p.heading,
        speed: p.speed,
        timestamp: p.timestamp,
      );

  factory UserLocation.fallback() => UserLocation(
        lat: AppConstants.defaultLat,
        lng: AppConstants.defaultLng,
        timestamp: DateTime.now(),
      );
}

/// Real GPS service — geolocator-backed. Handles permissions gracefully.
class LocationService {
  LocationService();

  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<UserLocation?> currentLocation({Duration? timeLimit}) async {
    if (!await ensurePermission()) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(timeLimit ?? const Duration(seconds: 10));
      return UserLocation.fromPosition(pos);
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : UserLocation.fromPosition(last);
      } catch (_) {
        return null;
      }
    }
  }

  Stream<UserLocation> watch({double distanceFilter = 5}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: distanceFilter.toInt(),
      ),
    ).map(UserLocation.fromPosition);
  }
}

final locationServiceProvider = Provider<LocationService>((_) => LocationService());

final currentLocationProvider = FutureProvider<UserLocation?>((ref) async {
  return ref.read(locationServiceProvider).currentLocation();
});
