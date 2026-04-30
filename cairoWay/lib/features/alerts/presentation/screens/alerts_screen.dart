import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/services/storage_service.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../profile/presentation/providers/settings_provider.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final incidents = ref.watch(storageServiceProvider).incidents();

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.incidentAlerts,
                  onChanged: ctrl.setIncidentAlerts,
                  title: const Text('Incident alerts'),
                  subtitle:
                      const Text('Get notified about incidents on your route'),
                  secondary: const Icon(Icons.report_gmailerrorred_rounded),
                ),
                SwitchListTile(
                  value: settings.voiceGuidance,
                  onChanged: ctrl.setVoiceGuidance,
                  title: const Text('Voice guidance'),
                  subtitle:
                      const Text('Spoken turn-by-turn during navigation'),
                  secondary: const Icon(Icons.record_voice_over_rounded),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text('Recent reports',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          if (incidents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No active incidents nearby.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          else
            for (final i in incidents)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.all(4),
                  child: ListTile(
                    leading: Text(
                      {
                        'accident': '🚧',
                        'heavyTraffic': '🚗',
                        'roadClosed': '🚫',
                        'police': '🚔',
                        'construction': '🏗️',
                        'hazard': '⚠️',
                      }[i.type.name]!,
                      style: const TextStyle(fontSize: 26),
                    ),
                    title: Text(i.type.name),
                    subtitle: Text(
                      '${i.note ?? '(no note)'} • ${DateFormat.jm().format(i.reportedAt)}',
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
