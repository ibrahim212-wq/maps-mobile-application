import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../models/commute_preferences.dart';
import '../models/saved_place.dart';
import '../providers/onboarding_state_provider.dart';
import '../services/onboarding_service.dart';
import '../widgets/map_location_picker.dart';
import 'commute_onboarding_page.dart';
import 'main_shell_screen.dart';

/// PRD: three steps — home, work, usual commute (time + days).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  static const _cairoLat = 30.0444;
  static const _cairoLng = 31.2357;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  String get _token => dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';

  void _toHome(WidgetRef r, SavedPlace p) {
    r.read(onboardingDraftProvider.notifier).state =
        r.read(onboardingDraftProvider).copyWith(home: p);
    _page.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _toWork(WidgetRef r, SavedPlace p) {
    r.read(onboardingDraftProvider.notifier).state =
        r.read(onboardingDraftProvider).copyWith(work: p);
    _page.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _completeOnboarding(
    WidgetRef r,
    OnboardingService svc,
    CommutePreferences commute,
  ) async {
    final draft = r.read(onboardingDraftProvider);
    final home = draft.home;
    final work = draft.work;
    if (home == null || work == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Set both home and work before continuing.'),
          ),
        );
      }
      return;
    }
    await svc.saveHome(home);
    await svc.saveWork(work);
    await svc.saveCommute(commute);
    await svc.setOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShellScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(onboardingServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to RouteMind'),
        leading: _index > 0
            ? IconButton(
                onPressed: () {
                  _page.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                icon: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: Column(
        children: [
          _StepDots(
            current: _index,
            total: 3,
          ),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                _StepHousing(
                  title: 'Where is your home?',
                  labelHint: 'e.g. Home in Nasr City',
                  defaultLabel: 'Home',
                  saveButtonText: 'Save home and continue',
                  mapboxToken: _token,
                  initialLat: _cairoLat,
                  initialLng: _cairoLng,
                  onSave: (p) => _toHome(ref, p),
                ),
                _StepHousing(
                  title: 'Where is your work?',
                  labelHint: 'e.g. Office in New Cairo',
                  defaultLabel: 'Work',
                  saveButtonText: 'Save work and continue',
                  mapboxToken: _token,
                  initialLat: _cairoLat,
                  initialLng: _cairoLng,
                  onSave: (p) => _toWork(ref, p),
                ),
                CommuteOnboardingPage(
                  onComplete: (c) => _completeOnboarding(ref, svc, c),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHousing extends StatelessWidget {
  const _StepHousing({
    required this.title,
    required this.labelHint,
    required this.defaultLabel,
    required this.saveButtonText,
    required this.mapboxToken,
    required this.initialLat,
    required this.initialLng,
    required this.onSave,
  });

  final String title;
  final String labelHint;
  final String defaultLabel;
  final String saveButtonText;
  final String mapboxToken;
  final double initialLat;
  final double initialLng;
  final void Function(SavedPlace) onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Text(
            'Set a name if you like, move the map or use the Cairo default, then use the button at the bottom.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: MapLocationPicker(
            mapboxToken: mapboxToken,
            labelHint: labelHint,
            defaultLabel: defaultLabel,
            saveButtonText: saveButtonText,
            initialLatitude: initialLat,
            initialLongitude: initialLng,
            onConfirm: onSave,
          ),
        ),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          total,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: i == current ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
