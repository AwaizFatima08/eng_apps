import 'package:flutter/material.dart';

import '../settings.dart';
import 'home_screen.dart';
import 'info_screens.dart';

/// Root widget shared by every toolkit app.
class PlantToolkitApp extends StatelessWidget {
  const PlantToolkitApp({
    super.key,
    required this.config,
    required this.settings,
  });

  final AppConfig config;
  final AppSettings settings;

  ThemeData _theme(Brightness b) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: config.seedColor,
      brightness: b,
    ),
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ConfigScope(
      config: config,
      child: SettingsScope(
        settings: settings,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => MaterialApp(
            title: config.appName,
            debugShowCheckedModeBanner: false,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            themeMode: settings.themeMode,
            home: settings.disclaimerAccepted
                ? const HomeScreen()
                : DisclaimerScreen(onAccept: settings.acceptDisclaimer),
          ),
        ),
      ),
    );
  }
}
