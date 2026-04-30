import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/services/storage_service.dart';

class AppSettings {
  final ThemeMode themeMode;
  final Locale locale;
  final bool voiceGuidance;
  final bool incidentAlerts;
  final bool trafficLayer;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.voiceGuidance = true,
    this.incidentAlerts = true,
    this.trafficLayer = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? voiceGuidance,
    bool? incidentAlerts,
    bool? trafficLayer,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
        voiceGuidance: voiceGuidance ?? this.voiceGuidance,
        incidentAlerts: incidentAlerts ?? this.incidentAlerts,
        trafficLayer: trafficLayer ?? this.trafficLayer,
      );
}

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._storage) : super(_load(_storage));
  final StorageService _storage;

  static AppSettings _load(StorageService s) {
    final theme = s.getSetting<String>(AppConstants.prefThemeMode);
    final locale = s.getSetting<String>(AppConstants.prefLocale);
    return AppSettings(
      themeMode: switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      locale: Locale(locale ?? 'en'),
      voiceGuidance:
          s.getSetting<bool>(AppConstants.prefVoiceGuidance) ?? true,
      incidentAlerts:
          s.getSetting<bool>(AppConstants.prefIncidentAlerts) ?? true,
      trafficLayer:
          s.getSetting<bool>(AppConstants.prefTrafficLayer) ?? true,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _storage.setSetting(AppConstants.prefThemeMode, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _storage.setSetting(AppConstants.prefLocale, locale.languageCode);
  }

  Future<void> setVoiceGuidance(bool v) async {
    state = state.copyWith(voiceGuidance: v);
    await _storage.setSetting(AppConstants.prefVoiceGuidance, v);
  }

  Future<void> setIncidentAlerts(bool v) async {
    state = state.copyWith(incidentAlerts: v);
    await _storage.setSetting(AppConstants.prefIncidentAlerts, v);
  }

  Future<void> setTrafficLayer(bool v) async {
    state = state.copyWith(trafficLayer: v);
    await _storage.setSetting(AppConstants.prefTrafficLayer, v);
  }
}

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>(
        (ref) => SettingsController(ref.watch(storageServiceProvider)));
