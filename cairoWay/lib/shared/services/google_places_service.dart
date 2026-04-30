import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../models/place.dart';

/// Google Places fallback for autocomplete + place details.
///
/// Used as a SECONDARY source when Mapbox Search Box returns thin results.
/// Google's POI database is significantly richer for Egyptian businesses,
/// universities, brands, and shops.
class GooglePlacesService {
  GooglePlacesService({http.Client? client})
      : _client = client ?? http.Client();
  final http.Client _client;

  bool get hasKey => AppConstants.googlePlacesKey.isNotEmpty;

  /// One-shot search returning resolved [Place]s. Resolves up to [limit]
  /// predictions via the Place Details API. Best used as a fallback path —
  /// Place Details is billable per call.
  Future<List<Place>> searchEgypt(
    String query, {
    double? proximityLat,
    double? proximityLng,
    int limit = 5,
    String language = 'en',
    String sessionToken = '',
  }) async {
    if (!hasKey) return const [];
    final preds = await _autocomplete(
      query,
      proximityLat: proximityLat,
      proximityLng: proximityLng,
      language: language,
      sessionToken: sessionToken,
    );
    if (preds.isEmpty) return const [];
    final out = <Place>[];
    for (final p in preds.take(limit)) {
      final place = await _details(
        p,
        language: language,
        sessionToken: sessionToken,
      );
      if (place != null) out.add(place);
    }
    return out;
  }

  Future<List<_GooglePred>> _autocomplete(
    String query, {
    double? proximityLat,
    double? proximityLng,
    String language = 'en',
    String sessionToken = '',
  }) async {
    final params = <String, String>{
      'input': query.trim(),
      'language': language,
      'components': 'country:eg',
      'key': AppConstants.googlePlacesKey,
      if (sessionToken.isNotEmpty) 'sessiontoken': sessionToken,
    };
    if (proximityLat != null && proximityLng != null) {
      params['location'] = '$proximityLat,$proximityLng';
      params['radius'] = '60000';
    }
    final uri = Uri.https('maps.googleapis.com',
        '/maps/api/place/autocomplete/json', params);
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final preds = (json['predictions'] as List?) ?? const [];
      return preds.map((p) {
        final m = p as Map<String, dynamic>;
        final structured =
            m['structured_formatting'] as Map<String, dynamic>?;
        return _GooglePred(
          placeId: m['place_id'] as String,
          mainText: (structured?['main_text'] as String?) ??
              (m['description'] as String? ?? ''),
          secondaryText: structured?['secondary_text'] as String?,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Place?> _details(
    _GooglePred pred, {
    String language = 'en',
    String sessionToken = '',
  }) async {
    final params = <String, String>{
      'place_id': pred.placeId,
      'fields': 'geometry/location,name,formatted_address,types',
      'language': language,
      'key': AppConstants.googlePlacesKey,
      if (sessionToken.isNotEmpty) 'sessiontoken': sessionToken,
    };
    final uri = Uri.https(
        'maps.googleapis.com', '/maps/api/place/details/json', params);
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final result = json['result'] as Map<String, dynamic>?;
      if (result == null) return null;
      final loc = (result['geometry']
          as Map<String, dynamic>?)?['location'] as Map<String, dynamic>?;
      if (loc == null) return null;
      final types = (result['types'] as List?)?.cast<String>() ?? const [];
      final name = (result['name'] as String?) ??
          (pred.mainText.isNotEmpty ? pred.mainText : 'Place');
      return Place(
        id: 'g:${pred.placeId}',
        name: name,
        address: (result['formatted_address'] as String?) ??
            pred.secondaryText,
        lat: (loc['lat'] as num).toDouble(),
        lng: (loc['lng'] as num).toDouble(),
        category: types.isEmpty ? null : types.first,
      );
    } catch (_) {
      return null;
    }
  }
}

class _GooglePred {
  final String placeId;
  final String mainText;
  final String? secondaryText;
  const _GooglePred({
    required this.placeId,
    required this.mainText,
    this.secondaryText,
  });
}

final googlePlacesServiceProvider =
    Provider<GooglePlacesService>((_) => GooglePlacesService());
