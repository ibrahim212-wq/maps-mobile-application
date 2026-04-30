import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../shared/models/route_option.dart';

class Fmt {
  Fmt._();

  static String duration(double seconds) {
    final s = seconds.round();
    if (s < 60) return '${s}s';
    final m = (s / 60).round();
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final mm = m % 60;
    return mm == 0 ? '${h}h' : '${h}h ${mm}m';
  }

  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  static String trafficLabel(TrafficLevel l) => switch (l) {
        TrafficLevel.free => 'Clear',
        TrafficLevel.light => 'Light traffic',
        TrafficLevel.moderate => 'Moderate traffic',
        TrafficLevel.heavy => 'Heavy traffic',
        TrafficLevel.gridlock => 'Gridlock',
      };

  static Color trafficColor(TrafficLevel l) => switch (l) {
        TrafficLevel.free => AppColors.trafficFree,
        TrafficLevel.light => AppColors.trafficLight,
        TrafficLevel.moderate => AppColors.trafficModerate,
        TrafficLevel.heavy => AppColors.trafficHeavy,
        TrafficLevel.gridlock => AppColors.trafficGridlock,
      };

  static IconData trafficIcon(TrafficLevel l) => switch (l) {
        TrafficLevel.free => Icons.check_circle_rounded,
        TrafficLevel.light => Icons.trending_up_rounded,
        TrafficLevel.moderate => Icons.warning_amber_rounded,
        TrafficLevel.heavy => Icons.error_rounded,
        TrafficLevel.gridlock => Icons.block_rounded,
      };
}
