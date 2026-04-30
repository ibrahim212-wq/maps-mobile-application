import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/ai_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  AiResult<WeeklyInsights> _insights = const AiInitializing();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ref.read(aiServiceProvider).weeklyInsights();
    if (!mounted) return;
    setState(() => _insights = res);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trips = ref.watch(storageServiceProvider).trips();
    final totalSeconds =
        trips.fold<double>(0, (a, t) => a + t.durationSeconds);
    final timeSaved = trips.fold<double>(0, (a, t) {
      final p = t.predictedSeconds;
      return p == null ? a : a + (p - t.durationSeconds).clamp(0, 9999);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This week',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('${trips.length} trips',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        )),
                const SizedBox(height: 4),
                Text(
                  'Time saved: ${Fmt.duration(timeSaved)} • Total: ${Fmt.duration(totalSeconds)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1),
          const SizedBox(height: 18),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded),
                    const SizedBox(width: 8),
                    Text('AI prediction accuracy',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 16),
                switch (_insights) {
                  AiInitializing<WeeklyInsights>() => _statusRow(
                      context,
                      'AI service initializing…',
                      icon: Icons.cloud_sync_rounded,
                    ),
                  AiUnavailable<WeeklyInsights>(reason: final r) => _statusRow(
                      context,
                      r,
                      icon: Icons.cloud_off_rounded,
                    ),
                  AiSuccess<WeeklyInsights>(data: final d) => Text(
                      'Accuracy: ${(d.aiAccuracy * 100).round()}%\nBest day: ${d.bestDay}\nTip: ${d.tip}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                },
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trips per day',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                SizedBox(height: 180, child: _chart(scheme, trips)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (trips.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No trips yet — start your first navigation to see insights.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('Recent trips',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                ...trips.take(10).map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(4),
                        child: ListTile(
                          leading: const Icon(Icons.directions_car_rounded),
                          title: Text(t.toName),
                          subtitle: Text(
                            '${Fmt.duration(t.durationSeconds)} • ${Fmt.distance(t.distanceMeters)}',
                          ),
                        ),
                      ),
                    )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statusRow(BuildContext context, String text, {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _chart(ColorScheme scheme, List trips) {
    // Aggregate trips per day-of-week
    final counts = List<int>.filled(7, 0);
    for (final t in trips) {
      counts[t.startedAt.weekday - 1]++;
    }
    final maxY =
        (counts.fold<int>(0, (a, b) => a > b ? a : b) + 1).toDouble();
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final i = v.toInt();
                if (i < 0 || i > 6) return const SizedBox.shrink();
                return Text(labels[i],
                    style: TextStyle(color: scheme.onSurfaceVariant));
              },
            ),
          ),
        ),
        maxY: maxY,
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: counts[i].toDouble(),
                gradient: AppColors.primaryGradient,
                width: 16,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }),
      ),
    );
  }
}
