import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../models/navigation_route.dart';
import '../models/route_step.dart';
import '../services/directions_service.dart';
import '../services/location_tracking_service.dart';

/// Drives custom turn-by-turn: progress, re-route, and voice (no map widgets).
class NavigationController extends ChangeNotifier {
  NavigationController({
    required this.accessToken,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationName,
    DirectionsService? directionsService,
    LocationTrackingService? locationService,
  })  : _directions = directionsService ?? DirectionsService(),
        _location = locationService ?? LocationTrackingService() {
    _tts = FlutterTts();
  }

  final String accessToken;
  final double destinationLat;
  final double destinationLng;
  final String destinationName;

  final DirectionsService _directions;
  final LocationTrackingService _location;
  late final FlutterTts _tts;

  StreamSubscription<geo.Position>? _posSub;
  Timer? _rerouteStability;

  /// Latest route; null after error or before load.
  NavigationRoute? _route;
  int _stepIndex = 0;

  /// Path length in meters; cached for ETA/ratio.
  double _totalPathMeters = 0;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isNavigating = false;
  bool _isRerouting = false;
  bool _locationServicesOff = false;
  bool _permissionDenied = false;
  bool _followUser = true;
  /// 0=none, 1=said 300m, 2=said 100m, 3=said at maneuver, for [current step].
  int _voiceMilestone = 0;
  int _voiceMilestoneForStep = -1;
  // Off-route: must be > 40 m for 5+ seconds.
  bool _offRoute = false;
  int _remainingPathStartIndex = 0;
  // --- Live UI state ---
  String _primaryInstruction = '';
  String _secondaryText = '';
  double _distanceToNextManeuverM = 0;
  double _remainingDistanceM = 0;
  int _etaSeconds = 0;
  geo.Position? _lastPos;

  NavigationRoute? get route => _route;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isNavigating => _isNavigating;
  bool get isRerouting => _isRerouting;
  bool get locationServicesOff => _locationServicesOff;
  bool get permissionDenied => _permissionDenied;
  bool get followUser => _followUser;
  String get primaryInstruction => _primaryInstruction;
  String get secondaryText => _secondaryText;
  double get distanceToNextManeuverM => _distanceToNextManeuverM;
  double get remainingDistanceM => _remainingDistanceM;
  int get etaSeconds => _etaSeconds;
  int get currentStepIndex => _stepIndex;
  geo.Position? get lastPosition => _lastPos;

  /// First polyline index used when drawing “remaining” route (for map trimming).
  int get remainingPathStartIndex => _remainingPathStartIndex;

  /// Initial fetch from current location to destination; call after [prepareLocation] succeeds.
  Future<void> loadRoute() async {
    if (accessToken.isEmpty && !kIsWeb) {
      _errorMessage = 'Mapbox access token is missing. Add MAPBOX_ACCESS_TOKEN to .env.';
      notifyListeners();
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final p = await _location.currentPosition();
      _lastPos = p;
      final r = await _directions.fetchRoute(
        accessToken: accessToken,
        originLng: p.longitude,
        originLat: p.latitude,
        destinationLng: destinationLng,
        destinationLat: destinationLat,
      );
      _applyNewRoute(r, resetStep: true);
    } on DirectionsException catch (e) {
      _errorMessage = e.message;
      _route = null;
    } on Object {
      _errorMessage = 'Could not load the route. Check your network connection.';
      _route = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// One-shot permission and location-service checks before first route.
  Future<void> prepareLocation() async {
    if (kIsWeb) {
      _locationServicesOff = false;
      _permissionDenied = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }
    _locationServicesOff = false;
    _permissionDenied = false;
    final svc = await _location.isLocationServiceEnabled();
    if (!svc) {
      _locationServicesOff = true;
      _errorMessage =
          'Location is turned off. Turn on device location in settings to start navigation.';
      notifyListeners();
      return;
    }
    final perm = await _location.requestPermission();
    if (perm == geo.LocationPermission.denied ||
        perm == geo.LocationPermission.deniedForever) {
      _permissionDenied = true;
      _errorMessage = 'Location permission is required to navigate.';
      notifyListeners();
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  void setFollowUser(bool v) {
    if (_followUser != v) {
      _followUser = v;
      notifyListeners();
    }
  }

  /// Re-centers the map on the user; enables follow.
  void recenter() {
    _followUser = true;
    notifyListeners();
  }

  Future<void> startNavigation() async {
    if (_route == null) return;
    if (_isNavigating) return;
    if (!kIsWeb) {
      await _configureTts();
    }
    _isNavigating = true;
    _followUser = true;
    await _posSub?.cancel();
    _posSub = _location.positionStream().listen(
      _onPosition,
      onError: (_) {
        // Stream errors are rare; keep last known position.
      },
    );
    notifyListeners();
  }

  Future<void> _configureTts() async {
    if (kIsWeb) {
      return;
    }
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    if (kIsWeb) {
      return;
    }
    if (text.isEmpty) return;
    if (!_isNavigating) return;
    try {
      await _tts.speak(text);
    } on Object {
      // TTS can fail on some emulators; ignore.
    }
  }

  void _onPosition(geo.Position pos) {
    if (!_isNavigating || _route == null) return;
    _lastPos = pos;
    final r = _route!;

    // Point-to-polyline distance: used for re-route and traveled length.
    final snap = _snapToPath(pos.latitude, pos.longitude, r.coordinates);
    _remainingPathStartIndex = snap.segmentIndex;
    _totalPathMeters = _pathLengthMeters(r.coordinates);
    final distFromStart = _distanceAlongPathToPoint(
      r.coordinates,
      snap,
    );
    // Remaining along original polyline (simple and stable for UI).
    _remainingDistanceM = math.max(0, _totalPathMeters - distFromStart);
    if (r.totalDurationSeconds > 0 && _totalPathMeters > 1) {
      final rRatio = _remainingDistanceM / r.totalDistanceMeters;
      _etaSeconds = (r.totalDurationSeconds * rRatio).round();
    } else {
      // Fallback: city driving speed.
      const assumed = 6.0; // m/s
      _etaSeconds = (_remainingDistanceM / assumed).round();
    }
    if (pos.speed > 0.5 && _remainingDistanceM > 20) {
      _etaSeconds = (_remainingDistanceM / pos.speed).round();
    }

    // Off-route: straight-line to route > 40 m (stable enough with snap distance).
    final off = snap.distanceToPathM > 40;
    if (off) {
      if (!_offRoute) {
        _offRoute = true;
        _rerouteStability?.cancel();
        _rerouteStability = Timer(const Duration(seconds: 5), _onRerouteTimeout);
      }
    } else {
      _offRoute = false;
      _rerouteStability?.cancel();
      _rerouteStability = null;
    }

    // Advance step when we get close to the maneuver; complete at destination.
    _updateStepProgress(pos, r);
    if (!_isNavigating) return;

    // Next maneuver distance: haversine to current step's maneuver.
    final r2 = _route!;
    final step = r2.steps[math.min(_stepIndex, r2.steps.length - 1)];
    _distanceToNextManeuverM = _haversineM(
      pos.latitude,
      pos.longitude,
      step.maneuverLat,
      step.maneuverLng,
    );
    if (_stepIndex >= r2.steps.length - 1) {
      _distanceToNextManeuverM = _haversineM(
        pos.latitude,
        pos.longitude,
        r2.destinationLat,
        r2.destinationLng,
      );
    }
    _updateInstructionText(r2, step);
    _maybeVoiceForStep(step);
    notifyListeners();
  }

  void _updateInstructionText(
    NavigationRoute r,
    RouteStep step,
  ) {
    _primaryInstruction = step.instruction;
    if (_stepIndex < r.steps.length - 1) {
      final next = r.steps[_stepIndex + 1];
      _secondaryText = 'Then: ${next.instruction}';
    } else {
      _secondaryText = 'Approaching $destinationName';
    }
  }

  void _updateStepProgress(geo.Position pos, NavigationRoute r) {
    if (_stepIndex >= r.steps.length) return;
    final s = r.steps[_stepIndex];
    final dManeuver = _haversineM(
      pos.latitude,
      pos.longitude,
      s.maneuverLat,
      s.maneuverLng,
    );
    if (_stepIndex == r.steps.length - 1) {
      // Final approach: use destination.
      if (_haversineM(
            pos.latitude,
            pos.longitude,
            r.destinationLat,
            r.destinationLng,
          ) <
          50) {
        unawaited(_completeNavigation());
      }
      return;
    }
    if (dManeuver < 32) {
      _stepIndex++;
      // [_maybeVoiceForStep] detects new step via _voiceMilestoneForStep != _stepIndex.
    }
  }

  Future<void> _completeNavigation() async {
    if (!_isNavigating) return;
    _primaryInstruction = 'You have arrived';
    _secondaryText = destinationName;
    await stopNavigation();
    notifyListeners();
  }

  /// Announces at 300m, 100m, and at the maneuver, once per step (strict order: 0→1→2→3).
  void _maybeVoiceForStep(RouteStep step) {
    if (!_isNavigating) return;
    if (_voiceMilestoneForStep != _stepIndex) {
      _voiceMilestoneForStep = _stepIndex;
      // Skip stale distance announcements when the step already has you close in.
      final d = _distanceToNextManeuverM;
      if (d < 20) {
        _voiceMilestone = 2;
      } else if (d < 100) {
        _voiceMilestone = 1;
      } else {
        _voiceMilestone = 0;
      }
    }
    final d = _distanceToNextManeuverM;
    if (d <= 20 && _voiceMilestone == 2) {
      _voiceMilestone = 3;
      unawaited(_speak(step.instruction));
      return;
    }
    if (d <= 100 && _voiceMilestone == 1) {
      _voiceMilestone = 2;
      unawaited(
        _speak(
          'In one hundred meters, ${step.instruction.toLowerCase()}',
        ),
      );
      return;
    }
    if (d <= 300 && _voiceMilestone == 0) {
      _voiceMilestone = 1;
      unawaited(
        _speak(
          'In three hundred meters, ${step.instruction.toLowerCase()}',
        ),
      );
    }
  }

  Future<void> _onRerouteTimeout() async {
    if (!_isNavigating || _route == null) return;
    if (!_offRoute) return;
    final pos = _lastPos;
    if (pos == null) return;
    _isRerouting = true;
    _primaryInstruction = 'Re-routing…';
    notifyListeners();
    try {
      final r = await _directions.fetchRoute(
        accessToken: accessToken,
        originLng: pos.longitude,
        originLat: pos.latitude,
        destinationLng: destinationLng,
        destinationLat: destinationLat,
      );
      _applyNewRoute(r, resetStep: true);
    } on DirectionsException {
      // Keep previous route; user may return.
    } on Object {
      // ignore
    } finally {
      _isRerouting = false;
      _offRoute = false;
      _rerouteStability?.cancel();
      _rerouteStability = null;
      notifyListeners();
    }
  }

  void _applyNewRoute(NavigationRoute r, {required bool resetStep}) {
    _route = r;
    if (resetStep) {
      _stepIndex = 0;
      _voiceMilestone = 0;
      _voiceMilestoneForStep = -1;
    }
    _totalPathMeters = _pathLengthMeters(r.coordinates);
    if (r.steps.isNotEmpty) {
      _primaryInstruction = r.steps.first.instruction;
      _secondaryText = r.steps.length > 1
          ? 'Then: ${r.steps[1].instruction}'
          : 'Follow the route';
    }
  }

  Future<void> stopNavigation() async {
    _isNavigating = false;
    await _posSub?.cancel();
    _posSub = null;
    _rerouteStability?.cancel();
    _rerouteStability = null;
    try {
      await _tts.stop();
    } on Object {
      // ignore
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _rerouteStability?.cancel();
    unawaited(_tts.stop());
    super.dispose();
  }

  // --- Geometry: polyline and Earth ---

  static double _haversineM(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dP = p2 - p1;
    final dL = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dP / 2) * math.sin(dP / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dL / 2) * math.sin(dL / 2);
    return 2 * r * math.asin(math.sqrt(math.min(1.0, a)));
  }

  static double _pathLengthMeters(List<List<double>> coords) {
    if (coords.length < 2) return 0;
    double s = 0;
    for (var i = 0; i < coords.length - 1; i++) {
      s += _haversineM(
        coords[i][1], coords[i][0], coords[i + 1][1], coords[i + 1][0],
      );
    }
    return s;
  }

  static _PathSnap _snapToPath(
    double lat,
    double lon,
    List<List<double>> coords,
  ) {
    if (coords.isEmpty) {
      return const _PathSnap(0, 0, 1e9, 0, 0);
    }
    if (coords.length == 1) {
      final d = _haversineM(lat, lon, coords[0][1], coords[0][0]);
      return _PathSnap(0, 0, d, lat, lon);
    }
    var bestD = 1.0e12;
    var bestI = 0;
    var bestT = 0.0;
    var clat = lat;
    var clon = lon;
    for (var i = 0; i < coords.length - 1; i++) {
      final a = coords[i];
      final b = coords[i + 1];
      final t = _tOnSegment(lat, lon, a, b);
      final slat = a[1] + t * (b[1] - a[1]);
      final slon = a[0] + t * (b[0] - a[0]);
      final d = _haversineM(lat, lon, slat, slon);
      if (d < bestD) {
        bestD = d;
        bestI = i;
        bestT = t;
        clat = slat;
        clon = slon;
      }
    }
    return _PathSnap(bestI, bestT, bestD, clat, clon);
  }

  /// Linear t of closest point in lat/lng; ok for <50 km segments in Egypt.
  static double _tOnSegment(
    double lat,
    double lon,
    List<double> a,
    List<double> b,
  ) {
    final dLng = b[0] - a[0];
    final dLat = b[1] - a[1];
    final l2 = dLng * dLng + dLat * dLat;
    if (l2 < 1e-20) {
      return 0;
    }
    var t = ((lon - a[0]) * dLng + (lat - a[1]) * dLat) / l2;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    return t;
  }

  /// Distance in meters from route start to [snap] point along the polyline.
  static double _distanceAlongPathToPoint(
    List<List<double>> coords,
    _PathSnap snap,
  ) {
    if (coords.length < 2) return 0;
    double s = 0;
    for (var i = 0; i < snap.segmentIndex; i++) {
      s += _haversineM(
        coords[i][1], coords[i][0], coords[i + 1][1], coords[i + 1][0],
      );
    }
    if (snap.segmentIndex < coords.length - 1) {
      final a = coords[snap.segmentIndex];
      s += _haversineM(
        a[1], a[0], snap.clat, snap.clon,
      );
    }
    return s;
  }
}

class _PathSnap {
  const _PathSnap(
    this.segmentIndex,
    this.t,
    this.distanceToPathM,
    this.clat,
    this.clon,
  );
  final int segmentIndex;
  final double t;
  final double distanceToPathM;
  final double clat;
  final double clon;
}
