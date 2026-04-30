import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/presentation/screens/alerts_screen.dart';
import '../../features/best_time/presentation/screens/best_time_screen.dart';
import '../../features/home/presentation/screens/home_shell.dart';
import '../../features/home/presentation/screens/map_screen.dart';
import '../../features/insights/presentation/screens/insights_screen.dart';
import '../../features/navigation/presentation/screens/navigation_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/saved_places_screen.dart';
import '../../features/routing/presentation/screens/route_options_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../shared/models/place.dart';
import '../../shared/models/route_option.dart';

class AppRoutes {
  static const home = '/';
  static const insights = '/insights';
  static const alerts = '/alerts';
  static const profile = '/profile';
  static const search = '/search';
  static const routeOptions = '/route-options';
  static const navigate = '/navigate';
  static const onboarding = '/onboarding';
  static const savedPlaces = '/saved-places';
  static const bestTime = '/best-time';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final shellKey = GlobalKey<NavigatorState>();
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      ShellRoute(
        navigatorKey: shellKey,
        builder: (ctx, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: MapScreen()),
          ),
          GoRoute(
            path: AppRoutes.insights,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: InsightsScreen()),
          ),
          GoRoute(
            path: AppRoutes.alerts,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AlertsScreen()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.search,
        pageBuilder: (_, state) => CustomTransitionPage(
          child: SearchScreen(
            initialQuery: (state.extra as Map?)?['query'] as String?,
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.routeOptions,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, Object?>?;
          return CustomTransitionPage(
            child: RouteOptionsScreen(
              destination: extra?['destination'] as Place,
              origin: extra?['origin'] as Place?,
            ),
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: animation.drive(Tween(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic))),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.navigate,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, Object?>;
          return CustomTransitionPage(
            child: NavigationScreen(
              route: extra['route'] as RouteOption,
              destination: extra['destination'] as Place,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.savedPlaces,
        builder: (_, __) => const SavedPlacesScreen(),
      ),
      GoRoute(
        path: AppRoutes.bestTime,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, Object?>;
          return CustomTransitionPage(
            child: BestTimeScreen(
              origin: extra['origin'] as Place,
              destination: extra['destination'] as Place,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    ],
  );
});
