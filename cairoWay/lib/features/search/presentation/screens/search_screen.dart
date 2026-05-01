import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../shared/models/place.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/services/places_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/widgets/shimmer_loader.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  // Incremented every keystroke. Async callbacks check it to discard
  // results from stale queries that resolved after a newer one.
  int _searchEpoch = 0;
  List<Place> _results = const [];
  bool _loading = false;
  UserLocation? _bias;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _ctrl.text = widget.initialQuery!;
      _onChanged(widget.initialQuery!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focus.requestFocus();
      _bias = await ref.read(locationServiceProvider).currentLocation();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String? _activeCategory;

  void _onChanged(String q) {
    _debounce?.cancel();
    final epoch = ++_searchEpoch;
    if (q.trim().isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      final storage = ref.read(storageServiceProvider);
      final recentIds = storage.recents().map((r) => r.id).toSet();
      final savedIds =
          storage.savedPlaces().map((s) => s.place.id).toSet();
      final svc = ref.read(placesServiceProvider);
      final r = await svc.autocomplete(
        q,
        proximityLat: _bias?.lat,
        proximityLng: _bias?.lng,
        recentIds: recentIds,
        savedIds: savedIds,
      );
      // Discard if the user has typed something new since this request fired.
      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _results = _applyCategoryFilter(r);
        _loading = false;
      });
    });
  }

  void _applyCategory(String? category) {
    setState(() => _activeCategory = category);
    if (_ctrl.text.trim().isEmpty && category != null) {
      // Use category as the query for a generic browse.
      _ctrl.text = category;
      _onChanged(category);
    } else if (_results.isNotEmpty) {
      setState(() => _results = _applyCategoryFilter(_results));
    } else if (_ctrl.text.trim().isNotEmpty) {
      _onChanged(_ctrl.text);
    }
  }

  List<Place> _applyCategoryFilter(List<Place> input) {
    final cat = _activeCategory;
    if (cat == null) return input;
    final wanted = _categoryKeywords[cat] ?? const <String>[];
    if (wanted.isEmpty) return input;
    return input.where((p) {
      final c = p.category?.toLowerCase() ?? '';
      final n = p.name.toLowerCase();
      return wanted.any((k) => c.contains(k) || n.contains(k));
    }).toList();
  }

  static const _categoryKeywords = <String, List<String>>{
    'Restaurants': ['restaurant', 'food', 'eat', 'diner'],
    'Cafes': ['cafe', 'coffee', 'bakery', 'patisserie'],
    'Gas': ['gas', 'fuel', 'petrol', 'station'],
    'Hospitals': ['hospital', 'clinic', 'medical', 'pharmacy', 'health'],
    'Schools': ['school', 'university', 'college', 'education', 'academy'],
    'Malls': ['mall', 'shopping', 'plaza', 'market', 'center'],
    'Parking': ['parking', 'garage', 'park'],
  };

  Future<void> _selectPlace(Place place) async {
    HapticFeedback.selectionClick();
    // Rotate session token so the next search starts a fresh billing session.
    ref.read(placesServiceProvider).renewSession();
    await ref.read(storageServiceProvider).addRecent(place);
    if (!mounted) return;
    context.pushReplacement(AppRoutes.routeOptions, extra: {'destination': place});
  }

  /// Returns the best Material icon for a [Place] based on its category
  /// and name keywords, so results look like a real maps app.
  IconData _iconForPlace(Place p) {
    final cat = (p.category ?? '').toLowerCase();
    final n = p.name.toLowerCase();
    if (cat.contains('restaurant') || cat.contains('food') ||
        n.contains('restaurant') || n.contains('مطعم')) {
      return Icons.restaurant_rounded;
    }
    if (cat.contains('cafe') || cat.contains('coffee') ||
        n.contains('cafe') || n.contains('coffee') || n.contains('كافيه')) {
      return Icons.local_cafe_rounded;
    }
    if (cat.contains('hospital') || cat.contains('clinic') ||
        cat.contains('medical') || n.contains('hospital') ||
        n.contains('مستشفى') || n.contains('clinic')) {
      return Icons.local_hospital_rounded;
    }
    if (cat.contains('pharmacy') || n.contains('pharmacy') ||
        n.contains('صيدلية')) {
      return Icons.medication_rounded;
    }
    if (cat.contains('gas') || cat.contains('fuel') ||
        cat.contains('petrol') || n.contains('محطة') || n.contains('وقود')) {
      return Icons.local_gas_station_rounded;
    }
    if (cat.contains('parking') || cat.contains('garage') ||
        n.contains('parking') || n.contains('موقف')) {
      return Icons.local_parking_rounded;
    }
    if (cat.contains('university') || cat.contains('school') ||
        cat.contains('college') || n.contains('university') ||
        n.contains('college') || n.contains('جامعة') || n.contains('مدرسة')) {
      return Icons.school_rounded;
    }
    if (cat.contains('mall') || cat.contains('shopping') ||
        n.contains('mall') || n.contains('plaza') || n.contains('مول')) {
      return Icons.shopping_bag_rounded;
    }
    if (cat.contains('hotel') || n.contains('hotel') || n.contains('فندق')) {
      return Icons.hotel_rounded;
    }
    if (cat.contains('mosque') || n.contains('mosque') ||
        n.contains('masjid') || n.contains('مسجد')) {
      return Icons.mosque_rounded;
    }
    if (cat.contains('park') || cat.contains('garden') ||
        n.contains('park') || n.contains('garden') || n.contains('حديقة')) {
      return Icons.park_rounded;
    }
    if (cat.contains('address') || cat.contains('street')) {
      return Icons.signpost_rounded;
    }
    if (cat.contains('neighborhood') ||
        cat.contains('locality') ||
        cat.contains('place')) {
      return Icons.location_city_rounded;
    }
    return Icons.place_rounded;
  }

  /// Builds a distance + address subtitle string for a result tile.
  /// When [_bias] is available the distance is prepended so the user
  /// immediately knows how far away each result is.
  String? _distanceText(Place p) {
    final bias = _bias;
    if (bias == null) return p.address;
    const deg2rad = math.pi / 180.0;
    const r = 6371000.0;
    final dLat = (p.lat - bias.lat) * deg2rad;
    final dLng = (p.lng - bias.lng) * deg2rad;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(bias.lat * deg2rad) *
            math.cos(p.lat * deg2rad) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final dist = r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distStr = dist < 1000
        ? '${dist.round()} m'
        : '${(dist / 1000).toStringAsFixed(1)} km';
    return p.address != null ? '$distStr · ${p.address}' : distStr;
  }

  Future<void> _useCurrentLocation() async {
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    final loc = await ref.read(locationServiceProvider).currentLocation();
    setState(() => _loading = false);
    if (!mounted) return;
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not access location.'),
      ));
      return;
    }
    final reverse = await ref
        .read(placesServiceProvider)
        .reverse(loc.lat, loc.lng);
    final place = reverse ??
        Place(
          id: 'current',
          name: 'Current location',
          lat: loc.lat,
          lng: loc.lng,
        );
    await _selectPlace(place);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final storage = ref.watch(storageServiceProvider);
    final recents = storage.recents();
    final saved = storage.savedPlaces();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: GlassContainer.pill(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        onChanged: _onChanged,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Search places in Cairo or Giza',
                          prefixIcon: Icon(Icons.search_rounded),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_ctrl.text.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _ctrl.clear();
                          _onChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
              ),
            ),
            // Category quick-filters
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CategoryChip(
                    label: 'All',
                    active: _activeCategory == null,
                    onTap: () => _applyCategory(null),
                  ),
                  for (final c in _categoryKeywords.keys)
                    _CategoryChip(
                      label: c,
                      active: _activeCategory == c,
                      onTap: () => _applyCategory(c),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                children: [
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.my_location_rounded,
                          color: Colors.white, size: 18),
                    ),
                    title: const Text('Use current location'),
                    subtitle: const Text('GPS-detected'),
                    onTap: _useCurrentLocation,
                  ),
                  if (saved.isNotEmpty) ...[
                    _SectionHeader(text: 'Saved places'),
                    for (final s in saved)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassContainer(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(4),
                          child: _PlaceTile(
                            icon: _iconForLabel(s.label),
                            title: s.label[0].toUpperCase() + s.label.substring(1),
                            subtitle: s.place.name,
                            onTap: () => _selectPlace(s.place),
                          ),
                        ),
                      ),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 8),
                    const ShimmerListTile(),
                    const ShimmerListTile(),
                    const ShimmerListTile(),
                  ] else if (_results.isNotEmpty) ...[
                    _SectionHeader(text: 'Results'),
                    for (final p in _results)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassContainer(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(4),
                          child: _PlaceTile(
                            icon: _iconForPlace(p),
                            title: p.name,
                            subtitle: _distanceText(p),
                            query: _ctrl.text.trim(),
                            onTap: () => _selectPlace(p),
                          ),
                        ),
                      ).animate().fadeIn(duration: 220.ms),
                  ] else if (_ctrl.text.trim().isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 56, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text('No results found',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            'Try a different search or remove the category filter.',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                          ),
                          if (_activeCategory != null) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => _applyCategory(null),
                              icon: const Icon(Icons.filter_alt_off_rounded),
                              label: const Text('Clear filter'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (recents.isNotEmpty) ...[
                    _SectionHeader(text: 'Recent searches'),
                    for (final r in recents)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassContainer(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(4),
                          child: _PlaceTile(
                            icon: Icons.history_rounded,
                            title: r.name,
                            subtitle: r.address,
                            onTap: () => _selectPlace(r),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForLabel(String label) => switch (label) {
        'home' => Icons.home_rounded,
        'work' => Icons.business_center_rounded,
        _ => Icons.bookmark_rounded,
      };
}

/// Renders [text] with every occurrence of [query] (case-insensitive,
/// Arabic-normalised) highlighted in bold using the primary color.
class _HighlightText extends StatelessWidget {
  const _HighlightText({required this.text, required this.query});
  final String text;
  final String query;

  static String _norm(String s) {
    var r = s.toLowerCase();
    r = r.replaceAll(RegExp('[\u0623\u0625\u0622\u0671]'), '\u0627');
    r = r.replaceAll('\u0629', '\u0647');
    r = r.replaceAll('\u0649', '\u064a');
    r = r.replaceAll('\u0624', '\u0648');
    r = r.replaceAll('\u0626', '\u064a');
    r = r.replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '');
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normText = _norm(text);
    final normQuery = _norm(query);
    if (normQuery.isEmpty || !normText.contains(normQuery)) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final spans = <TextSpan>[];
    int cursor = 0;
    int idx = normText.indexOf(normQuery);
    while (idx != -1 && cursor <= text.length) {
      if (idx > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, idx)));
      }
      final end = idx + normQuery.length;
      spans.add(TextSpan(
        text: text.substring(idx, end.clamp(0, text.length)),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ));
      cursor = end;
      idx = normText.indexOf(normQuery, cursor);
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          color: active ? Colors.white : scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: scheme.primary,
        backgroundColor: brightness == Brightness.dark
            ? scheme.surfaceContainerHighest
            : const Color(0x88F0F0F0),
        side: BorderSide.none,
        showCheckmark: false,
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.query,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primary.withValues(alpha: 0.12),
        child: Icon(icon, color: scheme.primary, size: 20),
      ),
      title: (query != null && query!.isNotEmpty)
          ? _HighlightText(text: title, query: query!)
          : Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              )),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
