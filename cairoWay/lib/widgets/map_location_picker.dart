import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/saved_place.dart';
import 'map_location_no_token.dart' show LocationFallbackPanel;
import 'map_location_picker_mapbox.dart' if (dart.library.html) 'map_location_picker_mapbox_stub.dart' as m;
import 'map_location_picker_web.dart';

/// Pannable map with center pin when Mapbox is available; otherwise a Cairo fallback. Never blocks onboarding.
class MapLocationPicker extends StatefulWidget {
  const MapLocationPicker({
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
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  final _label = TextEditingController();
  late final TextEditingController _lat;
  late final TextEditingController _lng;

  dynamic _map;
  var _mapInteractive = false;
  var _mapFailed = false;
  String? _mapError;
  var _mapRetryId = 0;
  String? _saveError;

  bool get _hasValidMapboxToken =>
      widget.mapboxToken.isNotEmpty &&
      !widget.mapboxToken.contains('YOUR_') &&
      !kIsWeb;

  bool get _showMap => _hasValidMapboxToken && !_mapFailed;

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

  void _onMapReady(dynamic map) {
    if (!mounted) return;
    setState(() {
      _map = map;
      _mapInteractive = true;
      _mapError = null;
      _saveError = null;
    });
  }

  void _onMapError(String message) {
    if (!mounted) return;
    setState(() {
      _map = null;
      _mapInteractive = false;
      _mapFailed = true;
      _mapError = message;
    });
  }

  void _retryMap() {
    setState(() {
      _mapFailed = false;
      _mapError = null;
      _map = null;
      _mapInteractive = false;
      _mapRetryId++;
    });
  }

  Future<void> _onSave() async {
    setState(() => _saveError = null);
    if (_showMap && _map != null && _mapInteractive) {
      try {
        // ignore: avoid_dynamic_calls
        final state = await _map.getCameraState();
        // ignore: avoid_dynamic_calls
        final c = state.center;
        // ignore: avoid_dynamic_calls
        final lat = c.coordinates.lat.toDouble() as double;
        // ignore: avoid_dynamic_calls
        final lng = c.coordinates.lng.toDouble() as double;
        if (!mounted) return;
        widget.onConfirm(
          SavedPlace(
            label: _resolvedLabel,
            latitude: lat,
            longitude: lng,
          ),
        );
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read the map. Using the coordinates from the form.'),
            ),
          );
        }
        if (!mounted) return;
        _completeWithDefaultCoords();
      }
    } else {
      _completeWithDefaultCoords();
    }
  }

  void _completeWithDefaultCoords() {
    final la = double.tryParse(_lat.text.trim());
    final ln = double.tryParse(_lng.text.trim());
    if (la == null || ln == null) {
      setState(
        () => _saveError = 'Enter valid numbers for latitude and longitude.',
      );
      return;
    }
    widget.onConfirm(
      SavedPlace(
        label: _resolvedLabel,
        latitude: la,
        longitude: ln,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return MapLocationWebPanel(
        mapboxToken: widget.mapboxToken,
        labelHint: widget.labelHint,
        defaultLabel: widget.defaultLabel,
        saveButtonText: widget.saveButtonText,
        initialLatitude: widget.initialLatitude,
        initialLongitude: widget.initialLongitude,
        onConfirm: widget.onConfirm,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: TextField(
            controller: _label,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Name (optional)',
              hintText: widget.labelHint,
            ),
          ),
        ),
        if (_saveError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Text(
              _saveError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.danger,
                  ),
            ),
          ),
        if (_hasValidMapboxToken) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              _mapInteractive
                  ? 'Pan the map, then continue.'
                  : _mapFailed
                      ? 'Edit coordinates in the form below if needed, then continue.'
                      : 'Map loading — you can still continue; default is central Cairo.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              'No map key — central Cairo; adjust below if you need to.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        Expanded(
          child: _showMap
              ? m.MapboxMapCenterPane(
                  key: ValueKey(_mapRetryId),
                  initialLatitude: widget.initialLatitude,
                  initialLongitude: widget.initialLongitude,
                  onMapReady: _onMapReady,
                  onMapError: _onMapError,
                )
              : LocationFallbackPanel(
                  latController: _lat,
                  lngController: _lng,
                  mapError: _mapError,
                  onRetryMap: _hasValidMapboxToken ? _retryMap : null,
                  showTokenHint: !_hasValidMapboxToken,
                ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _onSave,
              child: Text(widget.saveButtonText),
            ),
          ),
        ),
      ],
    );
  }
}
