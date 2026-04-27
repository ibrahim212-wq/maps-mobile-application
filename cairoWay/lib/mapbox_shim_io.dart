import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void setMapboxAccessTokenIfAny(String? token) {
  final t = token?.trim() ?? '';
  if (t.isNotEmpty) {
    MapboxOptions.setAccessToken(t);
  }
}
