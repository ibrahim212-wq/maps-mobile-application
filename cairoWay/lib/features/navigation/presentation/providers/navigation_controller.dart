import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/route_option.dart';

/// Immutable snapshot of live navigation progress.
class NavigationState {
  const NavigationState({
    required this.route,
    this.currentStepIndex = 0,
    this.distanceToNextManeuver = 0,
    this.remainingTotalDistance = 0,
    this.estimatedTimeRemaining = 0,
    this.currentSpeedMs = 0,
    this.traveledPercentage = 0,
    this.isRerouting = false,
    this.autoFollow = true,
  });

  final RouteOption route;
  final int currentStepIndex;
  final double distanceToNextManeuver;
  final double remainingTotalDistance;
  final double estimatedTimeRemaining;
  final double currentSpeedMs;
  final double traveledPercentage;
  final bool isRerouting;
  final bool autoFollow;

  RouteStep? get currentStep => route.steps.isEmpty
      ? null
      : route.steps[currentStepIndex.clamp(0, route.steps.length - 1)];

  NavigationState copyWith({
    RouteOption? route,
    int? currentStepIndex,
    double? distanceToNextManeuver,
    double? remainingTotalDistance,
    double? estimatedTimeRemaining,
    double? currentSpeedMs,
    double? traveledPercentage,
    bool? isRerouting,
    bool? autoFollow,
  }) =>
      NavigationState(
        route: route ?? this.route,
        currentStepIndex: currentStepIndex ?? this.currentStepIndex,
        distanceToNextManeuver:
            distanceToNextManeuver ?? this.distanceToNextManeuver,
        remainingTotalDistance:
            remainingTotalDistance ?? this.remainingTotalDistance,
        estimatedTimeRemaining:
            estimatedTimeRemaining ?? this.estimatedTimeRemaining,
        currentSpeedMs: currentSpeedMs ?? this.currentSpeedMs,
        traveledPercentage: traveledPercentage ?? this.traveledPercentage,
        isRerouting: isRerouting ?? this.isRerouting,
        autoFollow: autoFollow ?? this.autoFollow,
      );
}

/// Lightweight provider that holds the active [NavigationState].
/// The [NavigationScreen] drives mutations directly for performance —
/// no async gaps between GPS updates and state changes.
class NavigationController extends StateNotifier<NavigationState> {
  NavigationController(RouteOption initialRoute)
      : super(NavigationState(
          route: initialRoute,
          remainingTotalDistance: initialRoute.distanceMeters,
          estimatedTimeRemaining: initialRoute.durationSeconds,
        ));

  void updateProgress({
    int? stepIndex,
    double? distanceToNextManeuver,
    double? remainingMeters,
    double? remainingSeconds,
    double? speedMs,
    double? traveledPct,
  }) {
    state = state.copyWith(
      currentStepIndex: stepIndex,
      distanceToNextManeuver: distanceToNextManeuver,
      remainingTotalDistance: remainingMeters,
      estimatedTimeRemaining: remainingSeconds,
      currentSpeedMs: speedMs,
      traveledPercentage: traveledPct,
    );
  }

  void setRerouting(bool v) => state = state.copyWith(isRerouting: v);

  void setAutoFollow(bool v) => state = state.copyWith(autoFollow: v);

  void swapRoute(RouteOption fresh) => state = state.copyWith(
        route: fresh,
        currentStepIndex: 0,
        remainingTotalDistance: fresh.distanceMeters,
        estimatedTimeRemaining: fresh.durationSeconds,
        isRerouting: false,
      );
}

final navigationControllerProvider = StateNotifierProvider.family<
    NavigationController, NavigationState, RouteOption>(
  (ref, route) => NavigationController(route),
);
