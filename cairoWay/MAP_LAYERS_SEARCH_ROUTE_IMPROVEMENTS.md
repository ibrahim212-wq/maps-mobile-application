# Map Layers + Smart Search + Premium Route Line — Implementation Summary

## Overview
Implemented three major UX improvements:
1. **Google Maps-style map layer switcher** (Default / Satellite / Traffic)
2. **Smart Egyptian search** with transliteration + multi-factor ranking
3. **Premium route line rendering** with zoom-based widths + rounded caps

---

## 1. Map Layers Feature

### What Changed
- Added `MapLayer` enum: `defaultStyle`, `satellite`, `traffic`
- Created persistent layer selection via `MapLayerNotifier` + Hive storage
- Built branded layer picker bottom sheet with emerald gradient cards
- Wired layer switching into all map screens (home, navigation, route options)
- Implemented `onStyleLoaded` callback to re-draw routes/signals after basemap switch

### Files Modified
- `lib/features/home/presentation/widgets/map_view.dart`
  - Added `MapLayer` enum with labels, descriptions, icons
  - Updated `_styleFor()` to handle satellite (`mapbox://styles/mapbox/satellite-streets-v12`)
  - Added `onStyleLoaded` callback that fires after every style load
  - Modified `didUpdateWidget` to detect layer changes and reload style

- `lib/features/home/presentation/providers/map_layer_provider.dart` (NEW)
  - `MapLayerNotifier` loads/saves selected layer from Hive
  - Persists user choice across app restarts

- `lib/features/home/presentation/screens/map_screen.dart`
  - Updated layers sheet to show 3 basemap cards (Default/Satellite/Traffic)
  - Added `_LayerCard` widget with emerald gradient when selected
  - Wired `onStyleLoaded` to re-draw traffic signals after style switch
  - Passed `layer: ref.watch(mapLayerProvider)` to `MapView`

- `lib/features/navigation/presentation/screens/navigation_screen.dart`
  - Passed `layer: ref.watch(mapLayerProvider)` to navigation `MapView`
  - Added `onStyleLoaded` to re-draw route after mid-navigation style switch
  - **CRITICAL FIX:** Removed `onPanStart` from `GestureDetector` (kept only `onScaleStart`) to fix Flutter crash: "Having both a pan gesture recognizer and a scale gesture recognizer is redundant"

- `lib/features/routing/presentation/screens/route_options_screen.dart`
  - Passed `layer: ref.watch(mapLayerProvider)` to route preview `MapView`
  - Added `onStyleLoaded` to re-paint routes after basemap switch

### User Experience
- Tap **Layers** button → bottom sheet opens
- Choose **Default** (branded RouteMind light/dark), **Satellite** (real imagery), or **Traffic** (navigation-optimized)
- Selection persists after app restart
- During active navigation, switching to Satellite preserves the route line and navigation state
- Route lines, traffic signals, and markers automatically re-appear after style loads

---

## 2. Premium Route Line Rendering

### What Changed
- Replaced fixed-width route lines with **zoom-based interpolated widths**
- Added dark casing layer for contrast on any basemap (especially satellite)
- Enabled rounded line caps + joins for smooth, premium appearance
- Updated route color to vivid emerald (`#16D6A3`) for main route
- Made alternative routes muted teal with lower opacity

### Implementation Details
- `_zoomWidth(min, max)` generates Mapbox expression:
  ```dart
  ['interpolate', ['linear'], ['zoom'], 8, min, 14, (min+max)/2, 18, max]
  ```
- Main route: casing width 6–16px, line width 3.5–11px
- Alternative routes: width 2.5–7px with 55% opacity
- `_ensurePremiumLineLayer()` applies width expression via `setStyleLayerProperty`
- `_hexFromArgb()` converts ARGB colors to `rgba(r,g,b,a)` strings for Mapbox

### Visual Result
- Route line is slim at city overview (zoom 8–10)
- Thick and clear at street level (zoom 16–18)
- Smooth rounded corners at every turn
- Dark outline ensures readability on satellite imagery
- Matches Google Maps route line quality

---

## 3. Smart Egyptian Search

### What Changed
- Added **Egyptian transliteration aliases** for common places:
  - `zayed` → Sheikh Zayed City
  - `october` / `6 october` → 6th of October City
  - `nasr city` / `مدينة نصر` → Nasr City
  - `maadi` / `المعادي` → Maadi
  - `mohandessin` / `المهندسين` → Mohandessin
  - `zamalek` / `الزمالك` → Zamalek
  - `haram` / `الهرم` → Pyramids of Giza
  - `tahrir` / `التحرير` → Tahrir Square
  - `new cairo` / `التجمع` → New Cairo / Fifth Settlement
  - `giza` / `الجيزة` → Giza
  - `cairo` / `القاهرة` → Cairo

- Implemented **multi-factor Google-style ranking**:
  - **Text relevance (0–100):** exact match > starts-with > word-start > contains > address match
  - **Distance (0–60):** exponential decay (0km → 60, 5km → 36, 20km → 13, 50km → 5)
  - **Greater Cairo bias (+15):** bounding box 29.6–30.4°N, 30.7–31.9°E
  - **Category bonus (+10):** when query matches place category
  - **Far-result penalty (−40):** results > 200km away are likely noise

### Implementation Details
- `_expandEgyptianAliases(query)` appends canonical forms to user query
  - Direct hit: `"zayed"` → `"zayed Sheikh Zayed City"`
  - Substring hit: `"sheraton zayed"` → `"sheraton zayed Sheikh Zayed City"`
- `_buildRanker()` scores each place with combined factors
- Results sorted by descending score (higher = better)
- Falls back to Google Places when Mapbox returns < 3 results

### User Experience
- Typing `"zayed"` immediately shows Sheikh Zayed City (not random far places)
- Typing `"october"` prioritizes 6th of October City over distant matches
- Arabic queries (`"مدينة نصر"`) work seamlessly
- Nearby famous places appear before obscure far locations
- Partial names (`"mohand"`) match Mohandessin
- Search feels smart and context-aware like Google Maps

---

## Critical Bug Fix

### GestureDetector Pan + Scale Conflict
**Problem:** App crashed on "Start Navigation" with error:
```
Incorrect GestureDetector arguments.
Having both a pan gesture recognizer and a scale gesture recognizer is redundant;
scale is a superset of pan.
```

**Root Cause:** `navigation_screen.dart` had both `onPanStart` and `onScaleStart` in the same `GestureDetector`.

**Fix:** Removed `onPanStart`, kept only `onScaleStart`.
- Scale gesture handles all interactions: one-finger pan, pinch zoom, rotate
- User gesture detection still works correctly
- Recenter button logic unchanged

---

## Testing Checklist

### Map Layers
- [x] Tap Layers button → sheet opens with 3 cards
- [x] Select Satellite → map switches to satellite imagery
- [x] Route line remains visible on satellite view
- [x] Selection persists after app restart
- [x] During navigation, switching layers preserves route + camera
- [x] Traffic signals re-appear after style switch

### Route Line
- [x] Route line is smooth with rounded corners
- [x] Line width scales with zoom (slim far out, thick close up)
- [x] Dark casing visible on satellite imagery
- [x] Alternative routes are muted and thinner
- [x] No jagged/broken segments

### Smart Search
- [x] Typing "zayed" shows Sheikh Zayed City first
- [x] Typing "october" shows 6th of October City first
- [x] Arabic queries work (e.g., "مدينة نصر")
- [x] Partial names match (e.g., "mohand" → Mohandessin)
- [x] Nearby places prioritized over far places
- [x] No weird random international results

### Navigation Crash Fix
- [x] Start Navigation no longer crashes
- [x] User can pan/zoom map during navigation
- [x] Recenter button appears after user interaction
- [x] Recenter returns camera to user location
- [x] `flutter analyze` clean (0 issues)

---

## Files Changed Summary

### New Files
- `lib/features/home/presentation/providers/map_layer_provider.dart`

### Modified Files
- `lib/features/home/presentation/widgets/map_view.dart`
- `lib/features/home/presentation/screens/map_screen.dart`
- `lib/features/navigation/presentation/screens/navigation_screen.dart`
- `lib/features/routing/presentation/screens/route_options_screen.dart`
- `lib/shared/services/places_service.dart`

---

## Technical Notes

### Mapbox Style Loading
- Mapbox **wipes all custom sources/layers** when `loadStyleURI()` is called
- Solution: `onStyleLoaded` callback re-adds route lines, traffic signals, markers
- All screens now handle style switches gracefully

### Route Line Width Expression
- Mapbox supports dynamic expressions: `['interpolate', ['linear'], ['zoom'], ...]`
- Applied via `setStyleLayerProperty('line-width', jsonEncode(expression))`
- Ensures crisp rendering at all zoom levels

### Search Ranking Algorithm
- Combines multiple signals (text, distance, region, category)
- Exponential distance decay prevents far results from dominating
- Greater Cairo bounding box gives local results a boost
- Transliteration aliases expand query before hitting Mapbox API

---

## Next Steps (Optional Enhancements)

1. **Popular Nearby Suggestions:** Show top 5 nearby POIs before user types
2. **Recent Searches Integration:** Boost recently searched places in ranking
3. **Saved Places Priority:** Show Home/Work at top when relevant
4. **Category Icons:** Display restaurant/hospital/mall icons in search results
5. **Distance Labels:** Show "2.3 km away" for each result
6. **Route Line Traffic Segments:** Color-code route by congestion level

---

## Conclusion

All three features are fully implemented and tested:
- ✅ Map layers with persistent selection
- ✅ Premium smooth route lines with zoom-based widths
- ✅ Smart Egyptian search with transliteration + multi-factor ranking
- ✅ Critical navigation crash fixed
- ✅ `flutter analyze` clean

The app now delivers a **Google Maps / Apple Maps-grade** experience for Egyptian users.
