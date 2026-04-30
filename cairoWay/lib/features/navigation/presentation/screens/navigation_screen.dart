import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/place.dart';
import '../../../../shared/models/route_option.dart';
import '../../../../shared/models/trip.dart';
import '../../../../shared/services/directions_service.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../home/presentation/providers/map_layer_provider.dart';
import '../../../home/presentation/widgets/map_view.dart';
import '../../../profile/presentation/providers/settings_provider.dart';
import '../../data/services/turn_by_turn_service.dart';

/// Active turn-by-turn navigation. Uses Mapbox navigation styles, a 3D
/// follow camera, and a real distance-based trip status machine for honest
/// arrival vs. cancellation classification.
class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({
    super.key,
    required this.route,
    required this.destination,
  });
  final RouteOption route;
  final Place destination;

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  static const _uuid = Uuid();
  // Distance to destination at which the trip auto-completes.
  static const _arrivalThresholdMeters = 50.0;
  // Below this duration AND below this fraction-of-route, ending = "cancelled near start".
  static const _earlyCancelMaxDuration = Duration(minutes: 5);
  static const _earlyCancelMaxFraction = 0.10;

  StreamSubscription<UserLocation>? _sub;
  late TurnByTurnService _tts;
  // Mutable so we can swap the active route on a successful reroute.
  late RouteOption _route;
  late final DateTime _startedAt;
  int _stepIndex = 0;
  // Per-step TTS milestone flags — reset when step advances.
  bool _spoken500 = false;
  bool _spoken100 = false;
  bool _spokenAtTurn = false;
  double _remainingSeconds = 0;
  double _remainingMeters = 0;
  UserLocation? _currentLoc;
  double? _userBearing;
  // Smoothed bearing used to drive the camera so heading changes feel
  // continuous (no snap/jitter at every GPS sample).
  double _smoothedBearing = 0;
  double _distanceCoveredMeters = 0;
  bool _autoFollow = true;
  MapViewController? _map;
  bool _mapReady = false;
  Timer? _loadingTimeout;
  // Auto-resume follow after 5 s of no user interaction.
  Timer? _autoResumeTimer;
  double _currentSpeed = 0; // m/s
  DateTime? _lastLocationTime;
  double _distanceToNextTurn = 0; // meters
  // Last route-progress redraw timestamp (throttle to avoid hammering Mapbox).
  DateTime? _lastProgressDrawAt;
  // ─── Camera gesture detection ───
  // Counter of in-flight app-initiated camera animations.
  // _onCameraChanged only treats a change as a user gesture when this is 0.
  int _pendingCameraUpdates = 0;

  // ─── Off-route detection / rerouting ───
  // First time the user crossed the off-route distance threshold during the
  // current excursion. Reset whenever the user comes back near the route.
  DateTime? _offRouteSinceAt;
  // Last successful reroute timestamp — used as a cooldown so we don't
  // hammer the Directions API on bad GPS or continuous drift.
  DateTime? _lastRerouteAt;
  bool _isRerouting = false;
  // Distance (m) between the user GPS fix and the nearest point on the
  // active route polyline. Surfaced for debugging / UI later.
  double _distFromRoute = 0;
  // Off-route tuning constants. Picked to match Google Maps behavior:
  //   • > 40m perpendicular to route for ≥ 6s → off-route
  //   • OR > 25m AND heading diverges by > 60° → off-route immediately
  //   • Cooldown so we don't reroute more than once every 20s
  static const double _offRouteDistanceM = 40.0;
  static const double _offRouteHardDistanceM = 25.0;
  static const double _offRouteHeadingDiffDeg = 60.0;
  static const Duration _offRouteDuration = Duration(seconds: 6);
  static const Duration _rerouteCooldown = Duration(seconds: 20);
  
  // Navigation camera state — Google Maps-style driving view.
  // Closer zoom + steeper pitch so the road ahead feels prominent.
  static const double _navigationZoom = 17.8;
  static const double _navigationPitch = 60.0;
  // Distance (m) the camera "looks ahead" of the user along the heading,
  // pushing the puck toward the lower third of the screen.
  static const double _cameraLookAheadM = 50.0;
  
  // (replaced by _pendingCameraUpdates counter — more reliable than a boolean flag)

  // ─── Smoothness / throttle state ───
  // Minimum interval between camera follow animation calls.
  // With a 600ms animation and 550ms throttle, each ease-to completes
  // before the next fires — preventing mid-flight interruptions that
  // produce a choppy, stuttering camera feel.
  static const Duration _cameraThrottle = Duration(milliseconds: 550);
  DateTime? _lastCameraUpdateAt;
  // Low-pass–filtered snap position for camera centering.
  // Absorbs GPS jitter and discrete segment-index jumps, making the
  // camera glide instead of teleport between fixes.
  double _filteredLat = 0;
  double _filteredLng = 0;
  bool _posFilterReady = false;
  // Route progress index: monotonically advances to prevent the traveled
  // line from briefly shrinking on GPS bounces.
  int _bestProgressIdx = 0;
  // ETA / HUD setState throttle — avoids full widget-tree rebuilds on
  // every GPS update (which fires ≤ 1/s).
  DateTime? _lastHudUpdateAt;

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    _startedAt = DateTime.now();
    _remainingSeconds = _route.durationSeconds;
    _remainingMeters = _route.distanceMeters;
    
    // Safety timeout: force hide loading overlay after 3 seconds
    _loadingTimeout = Timer(const Duration(seconds: 3), () {
      if (!_mapReady && mounted) {
        debugPrint('NAV LOADING TIMEOUT - forcing map ready');
        setState(() => _mapReady = true);
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initTts();
      await _startTracking();
    });
  }

  Future<void> _initTts() async {
    final settings = ref.read(settingsControllerProvider);
    final isAr = settings.locale.languageCode == 'ar';
    _tts = TurnByTurnService(isArabic: isAr);
    if (!settings.voiceGuidance) return;
    await _tts.init();
  }

  Future<void> _startTracking() async {
    final ok = await ref.read(locationServiceProvider).ensurePermission();
    if (!ok) return;
    final settings = ref.read(settingsControllerProvider);
    final firstStep = _route.steps.isNotEmpty ? _route.steps.first : null;
    if (firstStep != null && settings.voiceGuidance) {
      await _tts.announceStart(firstStep);
    }

    _sub = ref
        .read(locationServiceProvider)
        .watch(distanceFilter: 5)
        .listen(_onMove);
  }

  void _onMove(UserLocation pos) {
    final prev = _currentLoc;
    final now = DateTime.now();
    _currentLoc = pos;
    
    // Calculate speed for dynamic zoom
    if (prev != null && _lastLocationTime != null) {
      final distance = _distMeters(prev.lat, prev.lng, pos.lat, pos.lng);
      final timeElapsed = now.difference(_lastLocationTime!).inMilliseconds / 1000.0;
      if (timeElapsed > 0) {
        _currentSpeed = distance / timeElapsed;
      }
    }
    _lastLocationTime = now;

    // Project user onto the active route. We use the projected ("snapped")
    // position for both progress rendering and camera follow so the puck
    // tracks the road instead of jittering on raw GPS noise — this is the
    // same trick Google Maps and Apple Maps use during driving navigation.
    final proj = _projectOnRoute(pos.lat, pos.lng, _route.geometry);
    _distFromRoute = proj.dist;
    final onRoute = proj.dist <= _offRouteDistanceM;
    final snapLat = onRoute ? proj.lat : pos.lat;
    final snapLng = onRoute ? proj.lng : pos.lng;
    
    // Update bearing — prefer GPS heading when valid, otherwise derive from
    // the route segment we're on (gives a clean "follow the road" feel
    // even when standing still or with low GPS quality).
    double? targetBearing;
    if (pos.heading != null && pos.heading! >= 0 && _currentSpeed > 1.5) {
      targetBearing = pos.heading;
    } else if (onRoute) {
      targetBearing = _bearingAlongRoute(proj.idx);
    } else if (prev != null) {
      targetBearing = _bearing(prev.lat, prev.lng, pos.lat, pos.lng);
    }
    if (targetBearing != null) {
      _userBearing = targetBearing;
      // Smoothly interpolate to avoid camera jitter on noisy headings.
      // 0.18 lerp gives more gradual rotation than 0.25 — comfortable
      // in a moving car without lag that hides real turns.
      _smoothedBearing = _lerpBearing(_smoothedBearing, targetBearing, 0.18);
    }
    if (prev != null) {
      _distanceCoveredMeters +=
          _distMeters(prev.lat, prev.lng, pos.lat, pos.lng);
    }

    // Auto-arrive when within threshold of destination.
    final toDest = _distMeters(
        pos.lat, pos.lng, widget.destination.lat, widget.destination.lng);
    if (toDest < _arrivalThresholdMeters) {
      _completeTrip(TripStatus.arrived);
      return;
    }

    // Off-route detection — trigger reroute if user has clearly left
    // the route. Two paths to reroute:
    //   (1) sustained drift — > 40m for ≥ 6s
    //   (2) sharp divergence — > 25m AND heading differs by > 60°
    _evaluateOffRoute(pos, proj, now);

    
    // Monotonic progress index — only advances, never retreats on a
    // GPS bounce. Prevents the traveled line from briefly shrinking.
    _bestProgressIdx = math.max(_bestProgressIdx, proj.idx);
    // When the monotonic index is ahead of the current projection point,
    // use the route vertex at that index as the split so the traveled
    // segment does not shrink back to the bounced GPS position.
    final splitLng = _bestProgressIdx > proj.idx
        ? _route.geometry[
                math.min(_bestProgressIdx, _route.geometry.length - 1)][0]
        : proj.lng;
    final splitLat = _bestProgressIdx > proj.idx
        ? _route.geometry[
                math.min(_bestProgressIdx, _route.geometry.length - 1)][1]
        : proj.lat;
    // Update the visible route progress (traveled vs remaining) at most
    // every 900ms — Mapbox source updates have a noticeable cost.
    final shouldRedrawProgress = _lastProgressDrawAt == null ||
        now.difference(_lastProgressDrawAt!).inMilliseconds > 900;
    if (shouldRedrawProgress && _map != null) {
      _lastProgressDrawAt = now;
      final traveled =
          _splitTraveled(_route.geometry, _bestProgressIdx, splitLng, splitLat);
      final remaining =
          _splitRemaining(_route.geometry, _bestProgressIdx, splitLng, splitLat);
      // Fire-and-forget — don't block the location update.
      unawaited(_map!.setRouteProgress(traveled: traveled, remaining: remaining));
    }
    
    if (_autoFollow && !_isRerouting) {
      _moveCameraToDriving(snapLat, snapLng);
    }

    if (_route.steps.isEmpty) {
      _refreshRemaining();
      return;
    }
    final step = _route.steps[_stepIndex];
    final target = step.maneuverLocation;
    if (target != null) {
      final dist = _distMeters(pos.lat, pos.lng, target[1], target[0]);
      // Advance step when within 50 m of the maneuver point.
      if (dist < 50 && _stepIndex < _route.steps.length - 1) {
        setState(() {
          _stepIndex++;
          // Reset all per-step TTS milestone flags for the new step.
          _spoken500 = false;
          _spoken100 = false;
          _spokenAtTurn = false;
        });
        // Force an immediate HUD refresh on step change.
        _lastHudUpdateAt = null;
      }
    }
    final next = _route.steps[_stepIndex];
    final nextLoc = next.maneuverLocation ?? [pos.lng, pos.lat];
    final nextDist = _distMeters(pos.lat, pos.lng, nextLoc[1], nextLoc[0]);
    _distanceToNextTurn = nextDist;
    final settings = ref.read(settingsControllerProvider);
    if (settings.voiceGuidance) {
      // 500 m — early warning
      if (nextDist <= 500 && nextDist > 100 && !_spoken500) {
        _spoken500 = true;
        _tts.announce500(next);
      }
      // 100 m — approaching reminder
      if (nextDist <= 100 && nextDist > 30 && !_spoken100) {
        _spoken100 = true;
        _tts.announce100(next);
      }
      // 30 m — take action now
      if (nextDist <= 30 && !_spokenAtTurn) {
        _spokenAtTurn = true;
        _tts.announceNow(next);
      }
    }
    _refreshRemaining();
  }

  void _refreshRemaining() {
    final now = DateTime.now();
    // Throttle HUD setState to 1.5 s — ETA changes slowly and rebuilds are costly.
    if (_lastHudUpdateAt != null &&
        now.difference(_lastHudUpdateAt!).inMilliseconds < 1500) {
      return;
    }
    _lastHudUpdateAt = now;

    // ─── Remaining distance: real Haversine from GPS to destination ───
    // More accurate than step-based because it accounts for within-step progress.
    double newRemainingMeters;
    final loc = _currentLoc;
    if (loc != null) {
      newRemainingMeters = _distMeters(
          loc.lat, loc.lng, widget.destination.lat, widget.destination.lng);
    } else {
      final consumedDist = _route.steps
          .take(_stepIndex)
          .fold<double>(0, (a, s) => a + s.distanceMeters);
      newRemainingMeters =
          (_route.distanceMeters - consumedDist).clamp(0, double.infinity);
    }

    // ─── Remaining time: blend speed-based + step-based ───
    // Speed-based ETA reacts instantly to real driving speed.
    // Step-based acts as an anchor from the original route estimate.
    final consumed = _route.steps
        .take(_stepIndex)
        .fold<double>(0, (a, s) => a + s.durationSeconds);
    final stepBased =
        (_route.durationSeconds - consumed).clamp(0.0, double.infinity);
    double newRemainingSeconds;
    if (_currentSpeed > 1.5 && newRemainingMeters > 0) {
      final speedBased = newRemainingMeters / _currentSpeed;
      // 40% speed-based, 60% step-based — avoids wild ETA swings at traffic lights.
      newRemainingSeconds = (speedBased * 0.4 + stepBased * 0.6)
          .clamp(0.0, double.infinity);
    } else {
      newRemainingSeconds = stepBased;
    }

    setState(() {
      _remainingSeconds = newRemainingSeconds;
      _remainingMeters = newRemainingMeters;
    });
  }

  // ─── Trip ending ───

  Future<void> _onEndTapped() async {
    HapticFeedback.mediumImpact();
    final loc = _currentLoc;
    final toDest = loc == null
        ? double.infinity
        : _distMeters(loc.lat, loc.lng, widget.destination.lat,
            widget.destination.lng);

    // Skip confirmation if already at destination.
    if (toDest < _arrivalThresholdMeters) {
      await _completeTrip(TripStatus.arrived);
      return;
    }

    final shouldEnd = await _confirmEnd(toDest);
    if (shouldEnd != true || !mounted) return;
    final elapsed = DateTime.now().difference(_startedAt);
    final fraction = _route.distanceMeters > 0
        ? _distanceCoveredMeters / _route.distanceMeters
        : 0;
    final status = (elapsed < _earlyCancelMaxDuration &&
            fraction < _earlyCancelMaxFraction)
        ? TripStatus.cancelledNearStart
        : TripStatus.cancelledMidway;
    await _completeTrip(status);
  }

  Future<bool?> _confirmEnd(double distanceToDest) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End navigation?'),
        content: Text(distanceToDest.isFinite
            ? "You're ${Fmt.distance(distanceToDest)} from your destination."
            : 'Are you sure you want to end the trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continue navigating'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End trip'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTrip(TripStatus status) async {
    if (_sub == null && status != TripStatus.arrived) return;
    await _sub?.cancel();
    _sub = null;
    _autoResumeTimer?.cancel();
    if (status == TripStatus.arrived) {
      await _tts.announceArrival();
    } else {
      await _tts.stop();
    }
    final endedAt = DateTime.now();
    final elapsed = endedAt.difference(_startedAt);
    final actual = elapsed.inSeconds.toDouble();

    // Only persist trips that actually went somewhere.
    if (status != TripStatus.cancelledNearStart) {
      await ref.read(storageServiceProvider).addTrip(Trip(
            id: _uuid.v4(),
            fromName: 'Trip start',
            toName: widget.destination.name,
            durationSeconds: actual,
            distanceMeters: widget.route.distanceMeters,
            distanceCoveredMeters: status == TripStatus.arrived
                ? widget.route.distanceMeters
                : _distanceCoveredMeters,
            predictedSeconds: widget.route.durationSeconds,
            startedAt: _startedAt,
            endedAt: endedAt,
            status: status,
          ));
    }
    if (!mounted) return;
    await _showCompletionSheet(status, actual);
    if (!mounted) return;
    context.pop();
  }

  Future<void> _showCompletionSheet(TripStatus status, double actual) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        switch (status) {
          case TripStatus.arrived:
            return _ArrivedSheet(
              actual: actual,
              predicted: widget.route.durationSeconds,
              destinationName: widget.destination.name,
            );
          case TripStatus.cancelledNearStart:
            return const _CancelledNearStartSheet();
          case TripStatus.cancelledMidway:
            return _CancelledMidwaySheet(
              coveredMeters: _distanceCoveredMeters,
              totalMeters: widget.route.distanceMeters,
            );
          case TripStatus.active:
          case TripStatus.paused:
            return const SizedBox.shrink();
        }
      },
    );
  }

  // ─── User Interaction ───

  /// Called whenever the map camera changes (user gesture or app animation).
  /// Pauses auto-follow only when [_pendingCameraUpdates] == 0, meaning
  /// the change came from a user gesture rather than our own easeTo call.
  void _onCameraChanged(dynamic cameraState) {
    if (_pendingCameraUpdates == 0 && _autoFollow) {
      debugPrint('NAV: Camera moved by user – pausing auto-follow');
      setState(() => _autoFollow = false);
      _scheduleAutoResume();
    }
  }

  /// Restarts the 5-second countdown to auto-resume follow mode after
  /// the user has manually panned the camera.
  void _scheduleAutoResume() {
    _autoResumeTimer?.cancel();
    _autoResumeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_autoFollow) {
        debugPrint('NAV: Auto-resuming follow mode after 5 s idle');
        setState(() => _autoFollow = true);
        final loc = _currentLoc;
        if (loc != null) {
          _enterDrivingCamera(
            lat: loc.lat,
            lng: loc.lng,
            heading: _userBearing,
            durationMs: 800,
          );
        }
      }
    });
  }

  /// Enter Google Maps-style driving camera mode centered on user.
  /// Pushes the camera ahead of the user along the heading so the puck
  /// lands in the lower part of the screen with the road ahead visible.
  Future<void> _enterDrivingCamera({
    required double lat,
    required double lng,
    double? heading,
    int durationMs = 800,
  }) async {
    debugPrint('NAV: Entering driving camera at ($lat, $lng) heading: $heading');
    
    // Calculate initial bearing from route if no heading
    double bearing = heading ?? 0;
    if (bearing == 0 && _route.geometry.length >= 2) {
      final start = _route.geometry[0];
      final next = _route.geometry[1];
      bearing = _bearing(start[1], start[0], next[1], next[0]);
    }
    // Seed the smoothed bearing and reset position filter so the
    // first follow update after recenter/start glides from the exact
    // current location rather than a stale filtered position.
    _smoothedBearing = bearing;
    _posFilterReady = false;
    _lastCameraUpdateAt = null;

    final ahead = _pointAhead(lat, lng, bearing, _cameraLookAheadM);

    // Increment pending counter so _onCameraChanged ignores this animation.
    _pendingCameraUpdates++;
    await _map?.followUser(
      ahead[0],
      ahead[1],
      zoom: _navigationZoom,
      pitch: _navigationPitch,
      bearing: bearing,
      durationMs: durationMs,
    );
    Future.delayed(Duration(milliseconds: durationMs + 150), () {
      if (_pendingCameraUpdates > 0) _pendingCameraUpdates--;
    });
  }

  // ─── Dynamic Camera ───

  /// Google Maps-style dynamic zoom based on speed and turn proximity.
  /// - Close to turns: zoom in (18-19) for precise guidance
  /// - Highway speed: zoom out (15-16) for overview
  /// - Urban driving: balanced zoom (16.5-17.5)
  double _calculateDynamicZoom(double speedMs, double distanceToTurn) {
    // Convert speed from m/s to km/h for easier thresholds
    final speedKmh = speedMs * 3.6;
    
    // Very close to turn (< 100m) - zoom in for precision
    if (distanceToTurn < 100 && distanceToTurn > 0) {
      return 18.5;
    }
    
    // Approaching turn (100-300m) - start zooming in
    if (distanceToTurn < 300 && distanceToTurn > 0) {
      return 17.8;
    }
    
    // Highway speed (>80 km/h) - zoom out for overview
    if (speedKmh > 80) {
      return 15.5;
    }
    
    // Fast urban (50-80 km/h) - medium zoom
    if (speedKmh > 50) {
      return 16.5;
    }
    
    // Slow urban/traffic (<50 km/h) - closer zoom
    return 17.2;
  }

  /// Dynamic pitch based on turn proximity.
  /// - Far from turn: higher pitch (60-65°) for immersive view
  /// - Close to turn: lower pitch (45-50°) for better turn visibility
  double _calculateDynamicPitch(double distanceToTurn) {
    // Very close to turn - flatten for better intersection view
    if (distanceToTurn < 100 && distanceToTurn > 0) {
      return 45.0;
    }
    
    // Approaching turn - slight flatten
    if (distanceToTurn < 300 && distanceToTurn > 0) {
      return 52.0;
    }
    
    // Normal navigation - immersive 3D view
    return 60.0;
  }

  // ─── Math ───

  double _distMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _bearing(double lat1, double lng1, double lat2, double lng2) {
    final phi1 = _rad(lat1);
    final phi2 = _rad(lat2);
    final dLng = _rad(lng2 - lng1);
    final y = math.sin(dLng) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
    final brng = math.atan2(y, x);
    return (brng * 180 / math.pi + 360) % 360;
  }

  double _rad(double deg) => deg * math.pi / 180;

  // ─── Route geometry helpers ───

  /// Project a GPS point onto the route polyline. Returns the segment
  /// index, the projected lat/lng on that segment, and the perpendicular
  /// distance in meters. Equirectangular projection is accurate enough
  /// at the scale of one route segment (≤ a few hundred meters).
  ({int idx, double lat, double lng, double dist}) _projectOnRoute(
      double lat, double lng, List<List<double>> geom) {
    if (geom.length < 2) {
      return (idx: 0, lat: lat, lng: lng, dist: double.infinity);
    }
    double bestDist = double.infinity;
    int bestIdx = 0;
    double bestLat = lat;
    double bestLng = lng;
    for (var i = 0; i < geom.length - 1; i++) {
      final ax = geom[i][0], ay = geom[i][1];
      final bx = geom[i + 1][0], by = geom[i + 1][1];
      final dx = bx - ax, dy = by - ay;
      final lenSq = dx * dx + dy * dy;
      double projLng, projLat;
      if (lenSq == 0) {
        projLng = ax;
        projLat = ay;
      } else {
        final t =
            (((lng - ax) * dx + (lat - ay) * dy) / lenSq).clamp(0.0, 1.0);
        projLng = ax + t * dx;
        projLat = ay + t * dy;
      }
      final d = _distMeters(lat, lng, projLat, projLng);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
        bestLat = projLat;
        bestLng = projLng;
      }
    }
    return (idx: bestIdx, lat: bestLat, lng: bestLng, dist: bestDist);
  }

  /// Build the traveled (already-passed) part of the route up to and
  /// including the user's projected point on segment [idx].
  List<List<double>> _splitTraveled(
      List<List<double>> geom, int idx, double projLng, double projLat) {
    if (geom.isEmpty) return const [];
    final out = <List<double>>[];
    for (var i = 0; i <= idx; i++) {
      out.add(geom[i]);
    }
    out.add([projLng, projLat]);
    return out;
  }

  /// Build the remaining (still-to-drive) part of the route starting at
  /// the user's projected point on segment [idx].
  List<List<double>> _splitRemaining(
      List<List<double>> geom, int idx, double projLng, double projLat) {
    if (geom.isEmpty) return const [];
    final out = <List<double>>[
      [projLng, projLat]
    ];
    for (var i = idx + 1; i < geom.length; i++) {
      out.add(geom[i]);
    }
    return out;
  }

  /// Bearing along the route at segment [idx] (looking forward).
  double _bearingAlongRoute(int idx) {
    final g = _route.geometry;
    if (g.length < 2) return _userBearing ?? 0;
    final i = idx.clamp(0, g.length - 2);
    return _bearing(g[i][1], g[i][0], g[i + 1][1], g[i + 1][0]);
  }

  /// Shortest-path interpolation between two compass bearings (degrees).
  /// Handles the 0/360 wrap so the camera never spins the long way around.
  double _lerpBearing(double a, double b, double t) {
    final diff = ((b - a + 540) % 360) - 180;
    return (a + diff * t + 360) % 360;
  }

  /// Project a point [meters] forward along [bearing] from (lat, lng).
  /// Used to push the camera center ahead of the user, leaving the puck
  /// in the lower part of the screen with the road ahead visible.
  List<double> _pointAhead(
      double lat, double lng, double bearing, double meters) {
    const r = 6371000.0;
    final brng = _rad(bearing);
    final lat1 = _rad(lat);
    final lng1 = _rad(lng);
    final dr = meters / r;
    final lat2 = math.asin(
        math.sin(lat1) * math.cos(dr) + math.cos(lat1) * math.sin(dr) * math.cos(brng));
    final lng2 = lng1 +
        math.atan2(math.sin(brng) * math.sin(dr) * math.cos(lat1),
            math.cos(dr) - math.sin(lat1) * math.sin(lat2));
    return [lat2 * 180 / math.pi, lng2 * 180 / math.pi];
  }

  // ─── Off-route / Rerouting ───

  void _evaluateOffRoute(UserLocation pos,
      ({int idx, double lat, double lng, double dist}) proj, DateTime now) {
    if (_isRerouting) return;
    if (_lastRerouteAt != null &&
        now.difference(_lastRerouteAt!) < _rerouteCooldown) {
      return;
    }
    if (_route.geometry.length < 2) return;

    final routeBearing = _bearingAlongRoute(proj.idx);
    final headingDiff = _userBearing == null
        ? 0.0
        : ((routeBearing - _userBearing! + 540) % 360 - 180).abs();

    // Path 1: sustained drift past the soft threshold.
    if (proj.dist > _offRouteDistanceM) {
      _offRouteSinceAt ??= now;
      if (now.difference(_offRouteSinceAt!) >= _offRouteDuration) {
        unawaited(_reroute(reason: 'drift'));
        return;
      }
    } else {
      _offRouteSinceAt = null;
    }

    // Path 2: sharp divergence — clearly on a different road.
    if (proj.dist > _offRouteHardDistanceM &&
        _currentSpeed > 2.0 &&
        headingDiff > _offRouteHeadingDiffDeg) {
      unawaited(_reroute(reason: 'divergence'));
    }
  }

  Future<void> _reroute({required String reason}) async {
    if (_isRerouting) return;
    final loc = _currentLoc;
    if (loc == null) return;
    debugPrint('NAV: rerouting (reason=$reason, dist=${_distFromRoute.toStringAsFixed(1)}m)');
    setState(() => _isRerouting = true);
    _lastRerouteAt = DateTime.now();
    _offRouteSinceAt = null;

    try {
      final brightness = Theme.of(context).brightness;
      final routes = await ref.read(directionsServiceProvider).driveRoutes(
            fromLat: loc.lat,
            fromLng: loc.lng,
            toLat: widget.destination.lat,
            toLng: widget.destination.lng,
            alternatives: false,
          );
      if (!mounted) return;
      if (routes.isEmpty) {
        debugPrint('NAV: reroute failed — no routes returned');
        return;
      }
      final fresh = routes.first;
      setState(() {
        _route = fresh;
        _stepIndex = 0;
        _spoken500 = false;
        _spoken100 = false;
        _spokenAtTurn = false;
        _remainingSeconds = fresh.durationSeconds;
        _remainingMeters = fresh.distanceMeters;
        _distanceCoveredMeters = 0;
      });
      // Reset per-route smoothness state so filters/indices are fresh
      // for the new route geometry.
      _bestProgressIdx = 0;
      _posFilterReady = false;
      _lastCameraUpdateAt = null;
      _lastHudUpdateAt = null;
      // Redraw the active route line with the new geometry.
      try {
        await _map?.drawRoute(
          fresh,
          color: brightness == Brightness.dark
              ? AppColors.darkPrimary
              : AppColors.lightPrimary,
        );
      } catch (e) {
        debugPrint('NAV REROUTE DRAW ERROR: $e');
      }
      // Reset progress source — nothing traveled on the new route yet.
      try {
        await _map?.setRouteProgress(traveled: const [], remaining: fresh.geometry);
      } catch (_) {}
      _tts.announceRerouting();
    } catch (e) {
      debugPrint('NAV REROUTE ERROR: $e');
    } finally {
      if (mounted) setState(() => _isRerouting = false);
    }
  }

  // ─── Camera ───

  /// Move the camera to a Google Maps-style driving view: look-ahead
  /// center, driving zoom/pitch, smoothed bearing. Marks the update as
  /// app-initiated so it doesn't trip the user-gesture detector.
  void _moveCameraToDriving(double lat, double lng) {
    final now = DateTime.now();
    // Throttle: enforce a minimum 550ms gap between camera calls.
    // With a 600ms animation this means each ease-to finishes before
    // the next starts — no mid-flight interruptions, buttery smooth.
    if (_lastCameraUpdateAt != null &&
        now.difference(_lastCameraUpdateAt!) < _cameraThrottle) {
      return;
    }
    _lastCameraUpdateAt = now;

    // Low-pass filter the snapped position with α = 0.35.
    // Smooths GPS jitter and segment-index jumps so the camera
    // glides along the road rather than teleporting between fixes.
    if (!_posFilterReady) {
      _filteredLat = lat;
      _filteredLng = lng;
      _posFilterReady = true;
    } else {
      _filteredLat = _filteredLat * 0.65 + lat * 0.35;
      _filteredLng = _filteredLng * 0.65 + lng * 0.35;
    }

    final zoom = _calculateDynamicZoom(_currentSpeed, _distanceToNextTurn);
    final pitch = _calculateDynamicPitch(_distanceToNextTurn);
    final bearing = _smoothedBearing;
    // Push camera center ahead of the user along the heading so the puck
    // sits roughly in the lower third of the screen.
    final ahead = _pointAhead(_filteredLat, _filteredLng, bearing, _cameraLookAheadM);
    // Increment pending counter before firing the animation so
    // _onCameraChanged knows this is app-initiated, not a user gesture.
    _pendingCameraUpdates++;
    _map?.followUser(
      ahead[0],
      ahead[1],
      zoom: zoom,
      pitch: pitch,
      bearing: bearing,
      durationMs: 600,
    );
    // Decrement after animation completes + small buffer.
    Future.delayed(const Duration(milliseconds: 750), () {
      if (_pendingCameraUpdates > 0) _pendingCameraUpdates--;
    });
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _autoResumeTimer?.cancel();
    _tts.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final step = _route.steps.isEmpty
        ? null
        : _route.steps[_stepIndex.clamp(0, _route.steps.length - 1)];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              brightness: brightness,
              variant: MapStyleVariant.navigation,
              layer: ref.watch(mapLayerProvider),
              initialLat: _currentLoc?.lat ?? widget.destination.lat,
              initialLng: _currentLoc?.lng ?? widget.destination.lng,
              initialZoom: 17,
              initialPitch: 60,
              initialBearing: _userBearing ?? 0,
              onCameraChanged: _onCameraChanged,
              onStyleLoaded: () async {
                  // Style switched mid-navigation (e.g. user toggled
                  // Satellite). Mapbox wiped our route layers — re-draw
                  // them so navigation guidance keeps working.
                  if (_map == null) return;
                  try {
                    await _map!.drawRoute(_route,
                        color: brightness == Brightness.dark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary);
                  } catch (e) {
                    debugPrint('NAV STYLE RELOAD ROUTE ERROR: $e');
                  }
                },
                onMapReady: (c) async {
                  debugPrint('NAV MAP CREATED');
                  _map = c;
                  try {
                    // Thick high-contrast route polyline — emerald green brand.
                    await c.drawRoute(_route,
                        color: brightness == Brightness.dark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary);
                    debugPrint('NAV ROUTE DRAWN');
                    
                    // CRITICAL: Start navigation with immediate driving camera on user
                    if (_currentLoc != null) {
                      await _enterDrivingCamera(
                        lat: _currentLoc!.lat,
                        lng: _currentLoc!.lng,
                        heading: _userBearing,
                        durationMs: 800,
                      );
                    } else {
                      // Fallback: show route overview if no location yet
                      await c.fitBounds(_route.geometry);
                    }
                    debugPrint('NAV CAMERA SET');
                    
                    if (mounted) {
                      debugPrint('NAV MAP READY TRUE');
                      _loadingTimeout?.cancel();
                      setState(() => _mapReady = true);
                      debugPrint('NAV LOADING OVERLAY HIDDEN');
                    }
                  } catch (e) {
                    debugPrint('NAV MAP SETUP ERROR: $e');
                    if (mounted) {
                      _loadingTimeout?.cancel();
                      setState(() => _mapReady = true);
                    }
                  }
                },
              ),
          ),
          // Premium maneuver card — Google Maps-grade UI
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: GlassContainer(
                  borderRadius: 24,
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main maneuver section
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Turn icon with emerald gradient
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.lightPrimary.withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _iconForManeuver(step?.maneuverType),
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Instruction + distance
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Large distance display
                                  if (step != null && _distanceToNextTurn > 0)
                                    Text(
                                      Fmt.distance(_distanceToNextTurn),
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.lightPrimary,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  // Instruction text
                                  Text(
                                    step?.instruction ?? 'Starting navigation…',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Close button
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.close_rounded, size: 24),
                              tooltip: 'Exit navigation',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Next turn preview (if available)
                      if (_stepIndex + 1 < _route.steps.length)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: scheme.onSurface.withValues(alpha: 0.05),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _iconForManeuver(_route.steps[_stepIndex + 1].maneuverType),
                                size: 20,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Then ${_route.steps[_stepIndex + 1].instruction.toLowerCase()}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, duration: 500.ms),
              ),
            ),
          ),
          // Rerouting banner — fades in while we fetch a new route after
          // the user has clearly left the planned path. Non-blocking, so
          // the map and gestures keep working underneath.
          if (_isRerouting)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 130, 16, 0),
                  child: GlassContainer(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.lightPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Rerouting…',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.lightPrimary,
                              ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 220.ms).slideY(begin: -0.2),
                ),
              ),
            ),
          // Premium recenter pill button — Google Maps-style labeled button
          if (!_autoFollow)
            Positioned(
              right: 16,
              bottom: 180,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(24),
                shadowColor: AppColors.lightPrimary.withValues(alpha: 0.35),
                child: InkWell(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    debugPrint('NAV: Recenter tapped - resuming auto-follow');
                    _autoResumeTimer?.cancel();
                    setState(() => _autoFollow = true);
                    final loc = _currentLoc;
                    if (loc != null) {
                      await _enterDrivingCamera(
                        lat: loc.lat,
                        lng: loc.lng,
                        heading: _userBearing,
                        durationMs: 600,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.my_location_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Recenter',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.85, 0.85)),
            ),
          // Small non-blocking loading indicator (top-right corner)
          if (!_mapReady)
            Positioned(
              top: 80,
              right: 16,
              child: GlassContainer(
                borderRadius: 12,
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: scheme.primary,
                    strokeWidth: 3,
                  ),
                ),
              ).animate().fadeIn(),
            ),
          // Premium bottom ETA card — Google Maps-grade
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GlassContainer(
                  borderRadius: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ETA info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    // Time remaining
                                    Text(
                                      Fmt.duration(_remainingSeconds),
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.lightPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Speed indicator
                                    if (_currentSpeed > 1)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: scheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${(_currentSpeed * 3.6).round()} km/h',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: AppColors.lightPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Distance and destination
                                Row(
                                  children: [
                                    Icon(
                                      Icons.navigation_rounded,
                                      size: 16,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${Fmt.distance(_remainingMeters)} • ${widget.destination.name}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // End navigation button
                          IconButton.filled(
                            onPressed: _onEndTapped,
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'End navigation',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, duration: 500.ms),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForManeuver(String? type) {
    switch (type) {
      case 'turn':
        return Icons.turn_right_rounded;
      case 'merge':
        return Icons.merge_rounded;
      case 'roundabout':
      case 'rotary':
        return Icons.roundabout_right_rounded;
      case 'arrive':
        return Icons.flag_rounded;
      case 'depart':
        return Icons.navigation_rounded;
      default:
        return Icons.directions_rounded;
    }
  }
}

// ─── Completion sheets ───

class _ArrivedSheet extends StatelessWidget {
  const _ArrivedSheet({
    required this.actual,
    required this.predicted,
    required this.destinationName,
  });
  final double actual;
  final double predicted;
  final String destinationName;

  @override
  Widget build(BuildContext context) {
    final accuracy = predicted > 0
        ? (1 - ((actual - predicted).abs() / predicted))
            .clamp(0, 1)
            .toDouble()
        : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 56, color: Colors.green),
          const SizedBox(height: 12),
          Text("You've arrived",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(destinationName,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          _StatsRow(
            actual: actual,
            predicted: predicted,
            accuracy: accuracy,
          ),
          const SizedBox(height: 20),
          PremiumButton(
              label: 'Done',
              icon: Icons.done_all_rounded,
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _CancelledNearStartSheet extends StatelessWidget {
  const _CancelledNearStartSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Navigation cancelled',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            "We won't save this trip — you barely got started.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 20),
          PremiumButton(
              label: 'Got it',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _CancelledMidwaySheet extends StatelessWidget {
  const _CancelledMidwaySheet({
    required this.coveredMeters,
    required this.totalMeters,
  });
  final double coveredMeters;
  final double totalMeters;

  @override
  Widget build(BuildContext context) {
    final pct = totalMeters > 0
        ? (coveredMeters / totalMeters * 100).clamp(0, 100).round()
        : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined,
              size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('Trip ended early',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'You travelled ${Fmt.distance(coveredMeters)} of ${Fmt.distance(totalMeters)}  ($pct%).',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 20),
          PremiumButton(
              label: 'Done',
              icon: Icons.done_rounded,
              onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.actual,
    required this.predicted,
    required this.accuracy,
  });
  final double actual;
  final double predicted;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(label: 'Trip', value: Fmt.duration(actual)),
        _Stat(label: 'Predicted', value: Fmt.duration(predicted)),
        _Stat(label: 'Accuracy', value: '${(accuracy * 100).round()}%'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      ],
    );
  }
}
