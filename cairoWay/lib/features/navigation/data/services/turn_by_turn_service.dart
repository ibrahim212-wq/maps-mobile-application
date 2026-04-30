import 'package:flutter_tts/flutter_tts.dart';

import '../../../../shared/models/route_option.dart';

/// Handles spoken turn-by-turn guidance with multi-distance announcements.
///
/// Announcement pattern per step:
///   • 500 m  – early warning (prepare for turn)
///   • 100 m  – approaching reminder
///   •  30 m  – confirm / take action
///   • step advance – next step read out
///
/// Arabic phrasing follows natural Egyptian driving speech.
class TurnByTurnService {
  TurnByTurnService({required this.isArabic});

  final bool isArabic;
  final _tts = FlutterTts();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage(isArabic ? 'ar-EG' : 'en-US');
      await _tts.setSpeechRate(isArabic ? 0.45 : 0.50);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
  }

  // ─── High-level guidance ───

  /// Announce the start of navigation (first step).
  Future<void> announceStart(RouteStep firstStep) {
    final instruction = _translate(firstStep.maneuverType, firstStep.maneuverModifier, firstStep.instruction);
    return speak(isArabic ? 'بدء التنقل. $instruction' : 'Starting navigation. $instruction');
  }

  /// Announce arrival at destination.
  Future<void> announceArrival() {
    return speak(isArabic ? 'وصلت لوجهتك' : "You have arrived at your destination");
  }

  /// Announce rerouting.
  Future<void> announceRerouting() {
    return speak(isArabic ? 'جاري إعادة الحساب' : 'Rerouting');
  }

  /// Announce at the 500 m threshold.
  Future<void> announce500(RouteStep step) {
    final action = _translate(step.maneuverType, step.maneuverModifier, step.instruction);
    return speak(isArabic ? 'بعد 500 متر، $action' : 'In 500 metres, $action');
  }

  /// Announce at the 100 m threshold.
  Future<void> announce100(RouteStep step) {
    final action = _translate(step.maneuverType, step.maneuverModifier, step.instruction);
    return speak(isArabic ? 'بعد 100 متر، $action' : 'In 100 metres, $action');
  }

  /// Announce at the maneuver point (≤ 30 m).
  Future<void> announceNow(RouteStep step) {
    final action = _translate(step.maneuverType, step.maneuverModifier, step.instruction);
    return speak(isArabic ? '$action الآن' : action);
  }

  // ─── Translation helpers ───

  /// Returns a natural-language instruction for the given maneuver.
  /// Uses Arabic phrasing when [isArabic] is true.
  String _translate(String? type, String? modifier, String fallback) {
    if (!isArabic) return fallback;

    switch (type) {
      case 'depart':
        return 'ابدأ الرحلة';
      case 'arrive':
        return 'وصلت لوجهتك';
      case 'continue':
        return 'كمل على طول';
      case 'merge':
        return 'ادخل على الطريق';
      case 'fork':
        return _arabicFork(modifier);
      case 'roundabout':
      case 'rotary':
        return 'ادخل الدوار';
      case 'exit roundabout':
      case 'exit rotary':
        return 'اخرج من الدوار';
      case 'turn':
        return _arabicTurn(modifier);
      case 'new name':
        return 'كمل على طول';
      case 'on ramp':
        return 'خد المنحدر';
      case 'off ramp':
        return 'اخرج من الطريق السريع';
      default:
        return fallback;
    }
  }

  String _arabicTurn(String? modifier) {
    switch (modifier) {
      case 'left':
        return 'خد يسار';
      case 'right':
        return 'خد يمين';
      case 'sharp left':
        return 'خد يسار حاد';
      case 'sharp right':
        return 'خد يمين حاد';
      case 'slight left':
        return 'خد يسار شوية';
      case 'slight right':
        return 'خد يمين شوية';
      case 'uturn':
        return 'استدر';
      case 'straight':
        return 'كمل على طول';
      default:
        return 'كمل على طول';
    }
  }

  String _arabicFork(String? modifier) {
    switch (modifier) {
      case 'left':
        return 'خد الفرع الأيسر';
      case 'right':
        return 'خد الفرع الأيمن';
      default:
        return 'خد الفرع';
    }
  }
}
