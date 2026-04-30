import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../providers/settings_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppConstants.appName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Smart traffic for Cairo & Giza',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(8),
            blur: 36,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bookmark_rounded),
                  title: const Text('Saved places'),
                  subtitle: const Text('Home, Work and favorites'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.savedPlaces),
                ),
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Set up commute'),
                  subtitle: const Text('Re-run onboarding flow'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.onboarding),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(8),
            blur: 36,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_rounded),
                  title: const Text('Theme'),
                  subtitle: Text(_themeLabel(settings.themeMode)),
                  trailing: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.light, icon: Icon(Icons.light_mode)),
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto)),
                      ButtonSegment(
                          value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => ctrl.setThemeMode(s.first),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: const Text('Language'),
                  trailing: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('EN')),
                      ButtonSegment(value: 'ar', label: Text('AR')),
                    ],
                    selected: {settings.locale.languageCode},
                    onSelectionChanged: (s) =>
                        ctrl.setLocale(Locale(s.first)),
                  ),
                ),
                SwitchListTile(
                  value: settings.voiceGuidance,
                  onChanged: ctrl.setVoiceGuidance,
                  title: const Text('Voice guidance'),
                  secondary: const Icon(Icons.record_voice_over_rounded),
                ),
                SwitchListTile(
                  value: settings.trafficLayer,
                  onChanged: ctrl.setTrafficLayer,
                  title: const Text('Traffic congestion overlay'),
                  secondary: const Icon(Icons.traffic_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(8),
            blur: 36,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About RouteMind'),
                  subtitle: Text(AppConstants.tagline),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppConstants.appName,
                    applicationVersion: '0.1.0',
                    applicationLegalese: '© 2026 RouteMind',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };
}
