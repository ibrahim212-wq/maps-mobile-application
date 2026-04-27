import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'data/cairo_web_preview_data.dart';
import 'core/platform/web_preview_state.dart';
import 'mapbox_shim_io.dart' if (dart.library.html) 'mapbox_shim_web.dart' as mapbox;
import 'routemind_app.dart';
import 'providers/onboarding_state_provider.dart';
import 'services/onboarding_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final mapToken = dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';
  mapbox.setMapboxAccessTokenIfAny(kIsWeb ? null : mapToken);
  if (kIsWeb) {
    WebPreviewState.setActivePolyline(
      CairoWebPreviewData.staticDemoRoute.coordinates,
    );
  }
  try {
    await Firebase.initializeApp();
  } on Object {
    // Add Firebase config files and run FlutterFire when ready.
  }
  await Hive.initFlutter();
  await Hive.openBox<dynamic>('routemind_cache');
  final onboarding = await OnboardingService.create();
  runApp(
    ProviderScope(
      overrides: [
        onboardingServiceProvider.overrideWithValue(onboarding),
      ],
      child: const RouteMindApp(),
    ),
  );
}
