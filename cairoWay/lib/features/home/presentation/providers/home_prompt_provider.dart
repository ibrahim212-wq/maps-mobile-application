import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/services/storage_service.dart';

/// Reactive flag controlling whether the Home/Work setup prompt is dismissed
/// for this device. Persisted in Hive under
/// [AppConstants.prefHomeWorkPromptDismissed].
class HomeWorkPromptController extends StateNotifier<bool> {
  HomeWorkPromptController(this._storage)
      : super(_initialValue(_storage)) {
    // Initial state also reflects whether the user already has Home or Work.
    if (!state &&
        (_storage.savedByLabel('home') != null ||
            _storage.savedByLabel('work') != null)) {
      _persistDismiss();
    }
  }

  final StorageService _storage;

  static bool _initialValue(StorageService s) {
    final stored =
        s.getSetting<bool>(AppConstants.prefHomeWorkPromptDismissed) ?? false;
    if (stored) return true;
    // Legacy migration: if the older onboarding-shown flag was set, respect it.
    return s.getSetting<bool>(AppConstants.prefOnboardingShown) ?? false;
  }

  /// Permanently dismiss the Home/Work prompt for this device.
  Future<void> dismiss() async {
    if (state) return;
    state = true;
    await _persistDismiss();
  }

  Future<void> _persistDismiss() async {
    await _storage.setSetting(
        AppConstants.prefHomeWorkPromptDismissed, true);
  }
}

final homeWorkPromptDismissedProvider =
    StateNotifierProvider<HomeWorkPromptController, bool>(
  (ref) => HomeWorkPromptController(ref.watch(storageServiceProvider)),
);
