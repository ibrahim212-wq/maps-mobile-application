import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../../data/cairo_web_preview_data.dart';
import '../../providers/home_map_providers.dart';
import '../../screens/home/home_map_view.dart';
import 'cairo_map_preview.dart';

/// Full-bleed Cairo map preview for Chrome (no Mapbox native view).
class WebHomeMapPreview extends ConsumerStatefulWidget {
  const WebHomeMapPreview({super.key});

  @override
  ConsumerState<WebHomeMapPreview> createState() => _WebHomeMapPreviewState();
}

class _WebHomeMapPreviewState extends ConsumerState<WebHomeMapPreview> {
  geo.Position? _puck;

  @override
  void initState() {
    super.initState();
    _puck = geo.Position(
      latitude: HomeMapView.cairoLat,
      longitude: HomeMapView.cairoLng,
      timestamp: DateTime.now(),
      accuracy: 12,
      altitude: 18,
      heading: 32,
      speed: 3.5,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
      speedAccuracy: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trafficOn = ref.watch(trafficOverlayEnabledProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        CairoMapPreview(
          routeLngLat: CairoWebPreviewData.staticDemoRoute.coordinates,
          userPosition: _puck,
          destinationLngLat: const [CairoWebPreviewData.demoDestinationLng, CairoWebPreviewData.demoDestinationLat],
          showTraffic: trafficOn,
          padding: 20,
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.traffic,
                    color: trafficOn ? Colors.orange.shade800 : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trafficOn
                          ? CairoWebPreviewData.trafficHeadlines[0]
                          : 'Traffic overlay off (toggle FAB)',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                'Web preview · mock GPS',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
