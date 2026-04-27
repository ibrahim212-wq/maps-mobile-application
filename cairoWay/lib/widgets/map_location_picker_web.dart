import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/cairo_web_preview_data.dart';
import 'web/cairo_map_preview.dart';
import '../models/saved_place.dart';
import 'map_location_no_token.dart' show LocationFallbackPanel;

/// Onboarding “map” in the browser: preview + same fallback and CTA as mobile.
class MapLocationWebPanel extends StatefulWidget {
  const MapLocationWebPanel({
    super.key,
    required this.mapboxToken,
    required this.labelHint,
    required this.defaultLabel,
    required this.saveButtonText,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onConfirm,
  });

  final String mapboxToken;
  final String labelHint;
  final String defaultLabel;
  final String saveButtonText;
  final double initialLatitude;
  final double initialLongitude;
  final ValueChanged<SavedPlace> onConfirm;

  @override
  State<MapLocationWebPanel> createState() => _MapLocationWebPanelState();
}

class _MapLocationWebPanelState extends State<MapLocationWebPanel> {
  final _label = TextEditingController();
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lat = TextEditingController(
      text: widget.initialLatitude.toStringAsFixed(5),
    );
    _lng = TextEditingController(
      text: widget.initialLongitude.toStringAsFixed(5),
    );
  }

  @override
  void dispose() {
    _label.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  String get _resolvedLabel {
    final t = _label.text.trim();
    return t.isEmpty ? widget.defaultLabel : t;
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = widget.mapboxToken.isNotEmpty &&
        !widget.mapboxToken.contains('YOUR_');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: TextField(
            controller: _label,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Name (optional)',
              hintText: widget.labelHint,
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _error!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.danger),
            ),
          ),
        if (hasToken)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              'Web preview: mock Cairo map. Coordinates are editable below.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              'No live map in this browser; use the default or edit below.',
              maxLines: 2,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        Expanded(
          child: hasToken
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 200,
                        child: CairoMapPreview(
                          routeLngLat:
                              CairoWebPreviewData.staticDemoRoute.coordinates,
                          showTraffic: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: LocationFallbackPanel(
                          latController: _lat,
                          lngController: _lng,
                          showTokenHint: false,
                        ),
                      ),
                    ],
                  ),
                )
              : LocationFallbackPanel(
                  latController: _lat,
                  lngController: _lng,
                  showTokenHint: true,
                ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final la = double.tryParse(_lat.text.trim());
                final ln = double.tryParse(_lng.text.trim());
                if (la == null || ln == null) {
                  setState(
                    () => _error = 'Use valid numbers for latitude and longitude.',
                  );
                  return;
                }
                setState(() => _error = null);
                widget.onConfirm(
                  SavedPlace(
                    label: _resolvedLabel,
                    latitude: la,
                    longitude: ln,
                  ),
                );
              },
              child: Text(widget.saveButtonText),
            ),
          ),
        ),
      ],
    );
  }
}
