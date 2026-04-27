import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'screens/splash_screen.dart';

class RouteMindApp extends ConsumerWidget {
  const RouteMindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'RouteMind',
      theme: buildCairoTheme(dark: false),
      darkTheme: buildCairoTheme(dark: true),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
