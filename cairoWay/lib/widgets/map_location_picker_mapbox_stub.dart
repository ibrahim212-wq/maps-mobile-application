import 'package:flutter/material.dart';

/// Web placeholder — not used in mobile onboarding flow.
class MapboxMapCenterPane extends StatelessWidget {
  const MapboxMapCenterPane({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onMapReady,
    required this.onMapError,
  });

  final double initialLatitude;
  final double initialLongitude;
  final void Function(dynamic map) onMapReady;
  final void Function(String message) onMapError;

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Color(0xFFE0E0E0));
  }
}
