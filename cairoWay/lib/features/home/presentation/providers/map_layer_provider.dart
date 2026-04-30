import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/storage_service.dart';
import '../widgets/map_view.dart';

/// Persistent selected map basemap (Default / Satellite / Traffic).
///
/// Loads the previously chosen layer from Hive on first read and writes
/// every change back so the user's preference survives app restarts.
class MapLayerNotifier extends StateNotifier<MapLayer> {
  MapLayerNotifier(this._storage) : super(_load(_storage));

  final StorageService _storage;

  static MapLayer _load(StorageService storage) {
    final raw = storage.getSetting<String>('map_layer_v1');
    return MapLayer.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => MapLayer.defaultStyle,
    );
  }

  Future<void> set(MapLayer layer) async {
    if (state == layer) return;
    state = layer;
    await _storage.setSetting<String>('map_layer_v1', layer.name);
  }
}

final mapLayerProvider =
    StateNotifierProvider<MapLayerNotifier, MapLayer>((ref) {
  return MapLayerNotifier(ref.read(storageServiceProvider));
});
