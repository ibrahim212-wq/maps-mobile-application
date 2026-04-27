import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/commute_preferences.dart';
import '../models/saved_place.dart';
import '../services/onboarding_service.dart';

final onboardingServiceProvider = Provider<OnboardingService>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

class OnboardingDraft {
  const OnboardingDraft({
    this.home,
    this.work,
    this.commute,
  });

  final SavedPlace? home;
  final SavedPlace? work;
  final CommutePreferences? commute;

  OnboardingDraft copyWith({
    SavedPlace? home,
    SavedPlace? work,
    CommutePreferences? commute,
  }) {
    return OnboardingDraft(
      home: home ?? this.home,
      work: work ?? this.work,
      commute: commute ?? this.commute,
    );
  }
}

final onboardingDraftProvider = StateProvider<OnboardingDraft>(
  (ref) => const OnboardingDraft(),
);
