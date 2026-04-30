import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../domain/models/best_time_request.dart';
import '../domain/models/time_suggestion.dart';

/// Common interface so the UI is decoupled from the transport.
/// Today: [MockBestTimeService]. After Azure deploy: [HttpBestTimeService].
abstract class BestTimeService {
  Future<BestTimeResult> getBestTime(BestTimeRequest request);
}

/// Real backend client. Hits `${AppConstants.aiBaseUrl}/best-time`.
/// Currently unused — wire it in via the provider once Azure goes live.
class HttpBestTimeService implements BestTimeService {
  HttpBestTimeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<BestTimeResult> getBestTime(BestTimeRequest request) async {
    final uri = Uri.parse('${AppConstants.aiBaseUrl}/best-time');
    final res = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode >= 400) {
      throw Exception('Best-time API ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return BestTimeResult.fromJson(json);
  }
}

/// Realistic Cairo-traffic mock used while the AI backend isn't deployed.
///
/// Generates 4 departure options based on:
///   * Hour-of-day Cairo traffic curve (rush hours peak around 8am / 5pm).
///   * Haversine route distance between origin/destination.
///   * Deterministic per-hour confidence in the 0.75–0.92 range.
///
/// One option is marked `isRecommended` — the one with the shortest
/// estimated duration, which is what the user actually cares about.
class MockBestTimeService implements BestTimeService {
  @override
  Future<BestTimeResult> getBestTime(BestTimeRequest request) async {
    // Simulate realistic AI inference latency.
    await Future<void>.delayed(const Duration(milliseconds: 850));

    final distanceKm = _haversineKm(
      request.fromLat,
      request.fromLng,
      request.toLat,
      request.toLng,
    );

    // Generate 4 candidate departure times spread across the search window.
    final stepMinutes =
        math.max(10, request.searchWindowMinutes ~/ 4);
    const optionCount = 4;

    final candidates = <TimeSuggestion>[];
    for (var i = 0; i < optionCount; i++) {
      // Distribute departures from (arrival - window) up to (arrival - 5 min).
      final minutesBeforeArrival =
          request.searchWindowMinutes - (i * stepMinutes);
      final departure = request.arrivalTime
          .subtract(Duration(minutes: minutesBeforeArrival.clamp(5, 600)));

      final level = _trafficForHour(departure.hour, departure.weekday);
      final speedKmh = _speedForLevel(level);
      final durationMin =
          math.max(5, ((distanceKm / speedKmh) * 60).round());
      final arrival = departure.add(Duration(minutes: durationMin));

      // Confidence: deterministic in 0.75..0.92, slightly lower for heavy.
      final base = 0.78 + ((departure.hour * 7 + i * 3) % 14) / 100.0;
      final adj = level == TrafficLevel.heavy || level == TrafficLevel.gridlock
          ? -0.04
          : 0.0;
      final confidence =
          (base + adj).clamp(0.75, 0.92).toDouble();

      candidates.add(TimeSuggestion(
        departureTime: departure,
        estimatedDurationMinutes: durationMin,
        arrivalTime: arrival,
        trafficLevel: level,
        confidenceScore: double.parse(confidence.toStringAsFixed(2)),
        isRecommended: false,
        reasoning: _reasoningFor(level, departure),
      ));
    }

    // Sort departures chronologically so the UI list reads naturally.
    candidates.sort((a, b) => a.departureTime.compareTo(b.departureTime));

    // Pick the shortest-duration option as recommended.
    var bestIdx = 0;
    for (var i = 1; i < candidates.length; i++) {
      if (candidates[i].estimatedDurationMinutes <
          candidates[bestIdx].estimatedDurationMinutes) {
        bestIdx = i;
      }
    }
    candidates[bestIdx] = candidates[bestIdx].copyWith(isRecommended: true);

    return BestTimeResult(
      routeDistanceKm: double.parse(distanceKm.toStringAsFixed(2)),
      junctionsAnalyzed: request.mapboxRouteJunctions.isEmpty
          ? 12
          : request.mapboxRouteJunctions.length,
      suggestions: candidates,
      // Mock is always "ready". Switch to "initializing" to test the
      // fallback UI from the real backend.
      aiStatus: 'ready',
    );
  }

  // ── Cairo heuristics ─────────────────────────────────────────────

  TrafficLevel _trafficForHour(int hour, int weekday) {
    // Friday (DateTime.friday == 5) is the Egyptian weekend day with very
    // different patterns — calm in the morning, busy in the evening.
    final isFriday = weekday == DateTime.friday;
    final isWeekend = isFriday || weekday == DateTime.saturday;

    if (hour >= 0 && hour < 6) return TrafficLevel.free;
    if (hour >= 6 && hour < 7) return TrafficLevel.light;
    if (hour >= 7 && hour < 9) {
      return isWeekend ? TrafficLevel.light : TrafficLevel.heavy;
    }
    if (hour >= 9 && hour < 11) {
      return isWeekend ? TrafficLevel.free : TrafficLevel.moderate;
    }
    if (hour >= 11 && hour < 14) return TrafficLevel.light;
    if (hour >= 14 && hour < 16) return TrafficLevel.moderate;
    if (hour >= 16 && hour < 19) {
      return isWeekend ? TrafficLevel.moderate : TrafficLevel.heavy;
    }
    if (hour >= 19 && hour < 21) return TrafficLevel.moderate;
    if (hour >= 21 && hour < 23) return TrafficLevel.light;
    return TrafficLevel.free;
  }

  /// Realistic Cairo average speeds (km/h) per level.
  double _speedForLevel(TrafficLevel level) {
    switch (level) {
      case TrafficLevel.free:
        return 52;
      case TrafficLevel.light:
        return 40;
      case TrafficLevel.moderate:
        return 28;
      case TrafficLevel.heavy:
        return 18;
      case TrafficLevel.gridlock:
        return 9;
    }
  }

  String _reasoningFor(TrafficLevel level, DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    switch (level) {
      case TrafficLevel.free:
        return 'Off-peak window around $hh:00 — roads typically clear.';
      case TrafficLevel.light:
        return 'Light flow expected near $hh:00 based on weekly pattern.';
      case TrafficLevel.moderate:
        return 'Moderate traffic — usual mid-day Cairo conditions.';
      case TrafficLevel.heavy:
        return 'Rush-hour band ($hh:00). Expect slowdowns at major junctions.';
      case TrafficLevel.gridlock:
        return 'Gridlock pattern — consider leaving earlier or later.';
    }
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
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

/// Toggle this provider override to swap mock for real backend later.
final bestTimeServiceProvider =
    Provider<BestTimeService>((_) => MockBestTimeService());
