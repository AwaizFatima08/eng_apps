import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'tools/tools.dart';

/// Must match pubspec `version`.
const String kAppVersion = '1.0.0 (1)';

final appConfig = AppConfig(
  appName: 'TitraLab',
  discipline: 'Lab Toolkit',
  seedColor: const Color(0xFF7B3FA0),
  tools: labTools,
  version: kAppVersion,
  aboutText:
      'Everyday calculations for QC lab chemists and analysts: solution preparation, concentration conversions, titration results, density correction, moisture/LOI, statistics and water-quality conversions. Every tool shows its formula, the '
      'standard it follows and worked examples you can load.',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(PlantToolkitApp(config: appConfig, settings: settings));
}
