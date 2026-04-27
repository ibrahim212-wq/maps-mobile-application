import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/web/web_home_map_preview.dart';
import 'home_map_mapbox_view.dart' if (dart.library.html) 'home_map_mapbox_view_stub.dart';

/// Home map: Mapbox on mobile/desktop native; stylized Cairo preview in Chrome.
class HomeMapView extends ConsumerWidget {
  const HomeMapView({super.key});

  static const double cairoLat = 30.0444;
  static const double cairoLng = 31.2357;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) {
      return const WebHomeMapPreview();
    }
    return const HomeMapMapboxView();
  }
}
