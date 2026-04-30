import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'RouteMind';
  static const String tagline =
      'Google Maps tells you traffic now. RouteMind tells you traffic when you arrive.';

  // Cairo center fallback
  static const double defaultLat = 30.0444;
  static const double defaultLng = 31.2357;
  static const double defaultZoom = 13.0;

  // Cairo + Giza loose bbox (used for biasing search)
  static const double bboxMinLng = 30.85;
  static const double bboxMinLat = 29.85;
  static const double bboxMaxLng = 31.55;
  static const double bboxMaxLat = 30.30;

  // Hive boxes
  static const String boxCache = 'routemind_cache';
  static const String boxRecents = 'routemind_recent_searches';
  static const String boxSavedPlaces = 'routemind_saved_places';
  static const String boxIncidents = 'routemind_incidents';
  static const String boxSettings = 'routemind_settings';
  static const String boxTrips = 'routemind_trips';

  // Settings keys
  static const String prefThemeMode = 'theme_mode';
  static const String prefLocale = 'locale';
  static const String prefOnboardingShown = 'onboarding_prompt_shown';
  static const String prefHomeWorkPromptDismissed = 'home_work_prompt_dismissed';
  static const String prefVoiceGuidance = 'voice_guidance_enabled';
  static const String prefIncidentAlerts = 'incident_alerts_enabled';
  static const String prefTrafficLayer = 'traffic_layer_enabled';

  // ─── Env-backed keys ───
  static String get mapboxToken =>
      dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';
  static String get googlePlacesKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';
  static String get tomtomKey => dotenv.env['TOMTOM_API_KEY']?.trim() ?? '';

  // AI service base URL — backend not built yet. Configurable via env.
  static String get aiBaseUrl =>
      dotenv.env['AI_BASE_URL']?.trim().isNotEmpty == true
          ? dotenv.env['AI_BASE_URL']!.trim()
          : 'https://api.routemind.ai/v1';
}
