import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../models/place.dart';
import 'google_places_service.dart';

/// Real autocomplete + reverse geocoding for Cairo & Giza.
///
/// Primary: Mapbox **Search Box API** (`/search/searchbox/v1`).
/// Fallback: Google Places (when Mapbox returns < 3 results).
///
/// Results are deduplicated by name+coordinates (within 50m) and ranked by
/// match strength then proximity.
class PlacesService {
  PlacesService({
    http.Client? client,
    GooglePlacesService? google,
  })  : _client = client ?? http.Client(),
        _google = google ?? GooglePlacesService();

  final http.Client _client;
  final GooglePlacesService _google;
  static const _uuid = Uuid();

  /// Per-search-session token for Mapbox billing attribution.
  /// Renewed after every place selection so each session is billed correctly.
  String _sessionToken = _uuid.v4();

  /// Call this once after the user selects a place from the suggestions.
  /// It rotates the session token so the next search is a fresh billable session.
  void renewSession() => _sessionToken = _uuid.v4();

  /// LRU-style in-memory result cache keyed by "query|lat4|lng4".
  /// Speeds up back-space/re-type flows and avoids redundant API calls.
  final Map<String, List<Place>> _queryCache = {};
  static const int _maxCacheSize = 60;

  /// Returns an autocomplete result list. Empty when offline or no token.
  ///
  /// Pipeline:
  ///   1. Check in-memory cache.
  ///   2. Normalize query (trim, fold case, Arabic normalization, expand aliases).
  ///   3. Hit Mapbox Search Box biased to user proximity, EG country.
  ///   4. If results are thin, fall back to Google Places (richer EG POIs).
  ///   5. Dedupe by normalized-name+coords.
  ///   6. Score every candidate on text-match + distance + EG-bias
  ///      + saved/recent boost and return the top [limit] sorted descending.
  Future<List<Place>> autocomplete(
    String query, {
    double? proximityLat,
    double? proximityLng,
    int limit = 10,
    String language = 'en,ar',
    Set<String> recentIds = const {},
    Set<String> savedIds = const {},
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final cacheKey =
        '$q|${proximityLat?.toStringAsFixed(4)}|${proximityLng?.toStringAsFixed(4)}';
    final cached = _queryCache[cacheKey];
    if (cached != null) return cached;

    // Expand transliteration aliases so users can match Egyptian places
    // without exact spelling ("zayed" -> "Sheikh Zayed City", etc.).
    final expandedQuery = _expandEgyptianAliases(q);

    final mapbox = await _searchBoxSuggest(
      expandedQuery,
      proximityLat: proximityLat,
      proximityLng: proximityLng,
      limit: limit,
      language: language,
    );

    // Fall back to Google when Mapbox is thin — much richer for EG POIs.
    final googleNeeded = mapbox.length < 3 && _google.hasKey;
    final google = googleNeeded
        ? await _google.searchEgypt(
            expandedQuery,
            proximityLat: proximityLat,
            proximityLng: proximityLng,
            limit: limit - mapbox.length,
            sessionToken: _sessionToken,
            language: _firstLang(language),
          )
        : const <Place>[];

    final merged = _dedup([...mapbox, ...google]);
    merged.sort(_buildRanker(
      q,
      proximityLat: proximityLat,
      proximityLng: proximityLng,
      recentIds: recentIds,
      savedIds: savedIds,
    ));
    final result = merged.take(limit).toList();

    // Evict oldest entry when cache is full.
    if (_queryCache.length >= _maxCacheSize) {
      _queryCache.remove(_queryCache.keys.first);
    }
    _queryCache[cacheKey] = result;
    return result;
  }

  // ─── Egyptian transliteration / aliases ───
  //
  // Map common English transliterations and short forms to the canonical
  // Mapbox-friendly query. Bidirectional: typing the Arabic name also
  // expands to include the English form so Mapbox matches either index.
  static const Map<String, List<String>> _egyptianAliases = {
    '6 october': ['6th of October', 'October City', 'مدينة 6 أكتوبر'],
    '6th october': ['6th of October', 'October City', 'مدينة 6 أكتوبر'],
    'october': ['6th of October City', 'مدينة 6 أكتوبر'],
    'اكتوبر': ['6th of October', 'مدينة 6 أكتوبر'],
    'أكتوبر': ['6th of October', 'مدينة 6 أكتوبر'],
    'السادس من اكتوبر': ['6th of October City'],
    'nasr city': ['Nasr City', 'مدينة نصر'],
    'مدينة نصر': ['Nasr City'],
    'new cairo': ['New Cairo', 'القاهرة الجديدة', 'التجمع الخامس'],
    'التجمع': ['Fifth Settlement', 'New Cairo'],
    'القاهرة الجديدة': ['New Cairo'],
    'maadi': ['Maadi', 'المعادي'],
    'المعادي': ['Maadi'],
    'mohandessin': ['Mohandessin', 'المهندسين'],
    'المهندسين': ['Mohandessin'],
    'zamalek': ['Zamalek', 'الزمالك'],
    'الزمالك': ['Zamalek'],
    'haram': ['Haram', 'الهرم', 'Pyramids of Giza'],
    'الهرم': ['Haram', 'Pyramids of Giza'],
    'sheikh zayed': ['Sheikh Zayed City', 'الشيخ زايد'],
    'zayed': ['Sheikh Zayed City', 'الشيخ زايد'],
    'الشيخ زايد': ['Sheikh Zayed City'],
    'زايد': ['Sheikh Zayed City'],
    'tahrir': ['Tahrir Square', 'ميدان التحرير'],
    'التحرير': ['Tahrir Square'],
    'giza': ['Giza', 'الجيزة'],
    'الجيزة': ['Giza'],
    'cairo': ['Cairo', 'القاهرة'],
    'القاهرة': ['Cairo'],
  };

  /// Normalize the query and append known aliases as additional context so
  /// Mapbox Search Box matches both the user's spelling and the canonical
  /// form. We keep the original tokens in the query to preserve relevance.
  String _expandEgyptianAliases(String raw) {
    final lower = raw.toLowerCase().trim();
    // Collapse whitespace.
    final collapsed = lower.replaceAll(RegExp(r'\s+'), ' ');
    // Direct hit: "zayed" -> "zayed Sheikh Zayed City الشيخ زايد"
    final direct = _egyptianAliases[collapsed];
    if (direct != null) return '$raw ${direct.first}';
    // Substring hit: "Sheraton el zayed" still picks up "zayed".
    for (final entry in _egyptianAliases.entries) {
      if (collapsed.contains(entry.key)) {
        return '$raw ${entry.value.first}';
      }
    }
    return raw;
  }

  /// Reverse-geocode a coordinate to a friendly place. Best-effort.
  Future<Place?> reverse(double lat, double lng) async {
    final token = AppConstants.mapboxToken;
    if (token.isEmpty) return null;
    final uri = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json',
    ).replace(queryParameters: {
      'access_token': token,
      'language': 'en,ar',
      'limit': '1',
    });
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final features = (json['features'] as List?) ?? const [];
      if (features.isEmpty) return null;
      final m = features.first as Map<String, dynamic>;
      final coords = (m['center'] as List).cast<num>();
      return Place(
        id: (m['id'] as String?) ?? _uuid.v4(),
        name: (m['text'] as String?) ?? 'Pinned location',
        address: m['place_name'] as String?,
        lng: coords[0].toDouble(),
        lat: coords[1].toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Mapbox Search Box ───

  Future<List<Place>> _searchBoxSuggest(
    String q, {
    double? proximityLat,
    double? proximityLng,
    int limit = 10,
    String language = 'en,ar',
  }) async {
    final token = AppConstants.mapboxToken;
    if (token.isEmpty) return const [];

    final params = <String, String>{
      'q': q,
      'access_token': token,
      'session_token': _sessionToken,
      'language': language,
      'country': 'eg',
      'limit': '$limit',
      'types': 'poi,address,street,place,locality,neighborhood',
    };
    if (proximityLat != null && proximityLng != null) {
      params['proximity'] = '$proximityLng,$proximityLat';
    } else {
      params['proximity'] =
          '${AppConstants.defaultLng},${AppConstants.defaultLat}';
    }
    final uri = Uri.https(
      'api.mapbox.com',
      '/search/searchbox/v1/suggest',
      params,
    );
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final suggestions = (json['suggestions'] as List?) ?? const [];

      // Search Box returns suggestions WITHOUT coordinates. We retrieve them
      // in parallel for the top-N suggestions.
      final retrieved = await Future.wait(
        suggestions.take(limit).map((s) {
          final m = s as Map<String, dynamic>;
          final mapboxId = m['mapbox_id'] as String?;
          if (mapboxId == null) {
            return Future.value(<Place>[]);
          }
          return _searchBoxRetrieve(
            mapboxId: mapboxId,
            language: language,
            fallback: m,
          );
        }),
      );
      return retrieved.expand((e) => e).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Place>> _searchBoxRetrieve({
    required String mapboxId,
    required String language,
    required Map<String, dynamic> fallback,
  }) async {
    final token = AppConstants.mapboxToken;
    final uri = Uri.https(
      'api.mapbox.com',
      '/search/searchbox/v1/retrieve/$mapboxId',
      {
        'access_token': token,
        'session_token': _sessionToken,
        'language': language,
      },
    );
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final features = (json['features'] as List?) ?? const [];
      return features.map((f) {
        final m = f as Map<String, dynamic>;
        final geom = m['geometry'] as Map<String, dynamic>?;
        final coords = (geom?['coordinates'] as List?)?.cast<num>();
        if (coords == null || coords.length < 2) {
          return null;
        }
        final props = (m['properties'] as Map<String, dynamic>?) ?? const {};
        final name =
            (props['name'] as String?) ?? (fallback['name'] as String? ?? '');
        final fullAddress = (props['full_address'] as String?) ??
            (props['place_formatted'] as String?) ??
            (fallback['full_address'] as String?) ??
            (fallback['place_formatted'] as String?);
        return Place(
          id: 'mb:$mapboxId',
          name: name.isEmpty ? 'Place' : name,
          address: fullAddress,
          lng: coords[0].toDouble(),
          lat: coords[1].toDouble(),
          category: props['poi_category']?.toString() ??
              props['feature_type']?.toString(),
        );
      }).whereType<Place>().toList();
    } catch (_) {
      return const [];
    }
  }

  // ─── Arabic / text normalization ───

  /// Normalize text for comparison: lowercase, collapse whitespace, apply
  /// Arabic letter unification so that أ/إ/آ → ا, ة → ه, ى → ي, ؤ → و,
  /// ئ → ي, and strip diacritics (harakat). Without this, "مدينه نصر"
  /// would never match "مدينة نصر" and rankings would be completely wrong.
  static String _normalize(String s) {
    var r = s.toLowerCase().trim();
    r = r.replaceAll(RegExp(r'\s+'), ' ');
    r = r.replaceAll(RegExp('[أإآٱ]'), 'ا');
    r = r.replaceAll('ة', 'ه');
    r = r.replaceAll('ى', 'ي');
    r = r.replaceAll('ؤ', 'و');
    r = r.replaceAll('ئ', 'ي');
    // Remove Arabic diacritics (U+064B–U+065F, U+0670 tatweel).
    r = r.replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '');
    return r;
  }

  // ─── Helpers ───

  String _firstLang(String langs) {
    final first = langs.split(',').first.trim();
    return first.isEmpty ? 'en' : first;
  }

  /// Deduplicate by normalized name + coordinates within 50m.
  List<Place> _dedup(List<Place> places) {
    final out = <Place>[];
    for (final p in places) {
      final normP = _normalize(p.name);
      final dup = out.any((o) =>
          _normalize(o.name) == normP &&
          _distanceMeters(o.lat, o.lng, p.lat, p.lng) < 50);
      if (!dup) out.add(p);
    }
    return out;
  }

  /// Multi-factor "Google Maps style" ranker. Higher score wins.
  ///
  /// Scoring axes:
  ///   * Text relevance — normalized exact/prefix/word/substring/address match
  ///   * Arabic normalization — ة=ه, أ=ا, ى=ي so Arabic typos still score
  ///   * Proximity — exponential decay, closer is better
  ///   * Greater Cairo / Giza / October regional anchor
  ///   * Saved place boost — user explicitly saved this place
  ///   * Recent search boost — user recently selected this place
  ///   * POI type boost — actual POIs rank above pure addresses
  ///   * Far-result penalty — results > 200km are almost always noise
  int Function(Place a, Place b) _buildRanker(
    String query, {
    double? proximityLat,
    double? proximityLng,
    Set<String> recentIds = const {},
    Set<String> savedIds = const {},
  }) {
    final q = _normalize(query);
    // Greater Cairo anchor (~Tahrir Square) used when proximity is unknown.
    const cairoLat = 30.0444;
    const cairoLng = 31.2357;

    double score(Place p) {
      // Normalize both query and candidate so Arabic letter variants,
      // diacritics, and case differences don't break comparisons.
      final name = _normalize(p.name);
      final addr = _normalize(p.address ?? '');
      double s = 0;

      // ── Text relevance (0–100) ─────────────────────────────────
      if (name == q) {
        s += 100; // exact match
      } else if (name.startsWith(q)) {
        s += 82; // prefix match — typing "maadi" shows "Maadi" first
      } else if (RegExp('(^|\\s)${RegExp.escape(q)}').hasMatch(name)) {
        s += 67; // word-boundary match inside name
      } else if (name.contains(q)) {
        s += 48; // substring anywhere in name
      } else if (addr.startsWith(q)) {
        s += 35;
      } else if (addr.contains(q)) {
        s += 22; // substring in address only
      }

      // Partial prefix bonus: each leading char of q that is in name.
      // Gives a smooth relevance ramp-up as the user types.
      if (q.length >= 2 && q.length < name.length) {
        int prefixLen = 0;
        for (var i = 0; i < q.length && i < name.length; i++) {
          if (q[i] == name[i]) {
            prefixLen++;
          } else {
            break;
          }
        }
        s += prefixLen * 1.5;
      }

      // ── Distance (0–60, exponential decay) ─────────────────────
      final lat = proximityLat ?? cairoLat;
      final lng = proximityLng ?? cairoLng;
      final dKm = _distanceMeters(p.lat, p.lng, lat, lng) / 1000.0;
      // 0km → 60, 5km → ~36, 20km → ~13, 50km → ~5, 200km → ~0
      s += 60 * math.exp(-dKm / 18.0);

      // Hard penalty for far-away noise (e.g. "October" in Europe).
      if (dKm > 200) s -= 45;

      // ── Greater Cairo / Giza / October / Sheikh Zayed (0–15) ───
      final inGreaterCairo = p.lat > 29.6 &&
          p.lat < 30.4 &&
          p.lng > 30.7 &&
          p.lng < 31.9;
      if (inGreaterCairo) s += 15;

      // ── POI type boost (0–12) ──────────────────────────────────
      final cat = _normalize(p.category ?? '');
      final isPoi = cat.isNotEmpty &&
          !cat.contains('address') &&
          !cat.contains('street') &&
          !cat.contains('locality');
      if (isPoi) s += 8;
      // Category keyword match bonus.
      if (q.length >= 3 && cat.contains(q)) s += 12;

      // ── Personalization boosts ─────────────────────────────────
      if (savedIds.contains(p.id)) s += 30;
      if (recentIds.contains(p.id)) s += 20;

      return s;
    }

    return (a, b) => score(b).compareTo(score(a));
  }

  double _distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}

final placesServiceProvider =
    Provider<PlacesService>((_) => PlacesService());
