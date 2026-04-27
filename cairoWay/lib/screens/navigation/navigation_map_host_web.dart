import 'package:flutter/material.dart';

import '../../controllers/navigation_controller.dart';
import '../../widgets/web/cairo_map_preview.dart';

/// Web: stylized map + live route (mock GPS). See [NavigationMapHost] on IO.
class NavigationMapHost extends StatelessWidget {
  const NavigationMapHost({
    super.key,
    required this.controller,
    required this.destinationLat,
    required this.destinationLng,
    required this.onUserPan,
  });

  final NavigationController controller;
  final double destinationLat;
  final double destinationLng;
  final VoidCallback onUserPan;

  @override
  Widget build(BuildContext context) {
    return WebNavigationMapPreview(
      controller: controller,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      onUserPan: onUserPan,
    );
  }
}
