import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/commute_preferences.dart';
import '../models/saved_place.dart';

const _kOnboardingComplete = 'routemind_onboarding_complete';
const _kHome = 'routemind_home';
const _kWork = 'routemind_work';
const _kCommute = 'routemind_commute';

class OnboardingService {
  OnboardingService(this._prefs);

  final SharedPreferences _prefs;

  static Future<OnboardingService> create() async {
    final p = await SharedPreferences.getInstance();
    return OnboardingService(p);
  }

  bool get isOnboardingComplete => _prefs.getBool(_kOnboardingComplete) ?? false;

  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(_kOnboardingComplete, true);
  }

  Future<void> saveHome(SavedPlace place) async {
    await _prefs.setString(_kHome, jsonEncode(place.toJson()));
  }

  Future<void> saveWork(SavedPlace place) async {
    await _prefs.setString(_kWork, jsonEncode(place.toJson()));
  }

  Future<void> saveCommute(CommutePreferences prefs) async {
    await _prefs.setString(_kCommute, jsonEncode(prefs.toJson()));
  }

  SavedPlace? get home {
    final raw = _prefs.getString(_kHome);
    if (raw == null) return null;
    return SavedPlace.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  SavedPlace? get work {
    final raw = _prefs.getString(_kWork);
    if (raw == null) return null;
    return SavedPlace.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  CommutePreferences? get commute {
    final raw = _prefs.getString(_kCommute);
    if (raw == null) return null;
    return CommutePreferences.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}
