import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom index: 0 Home, 1 Insights, 2 Alerts, 3 Profile.
final mainTabIndexProvider = StateProvider<int>((ref) => 0);

/// Mapbox real-time traffic line overlay (Mapbox traffic tileset).
final trafficOverlayEnabledProvider = StateProvider<bool>((ref) => true);

/// AI smart card: expanded (full content) vs collapsed (handle only).
final aiSmartCardExpandedProvider = StateProvider<bool>((ref) => true);
