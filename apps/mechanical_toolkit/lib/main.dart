import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'tools/tools.dart';

/// Must match pubspec `version`.
const String kAppVersion = '1.0.0 (1)';

final appConfig = AppConfig(
  appName: 'TorqueMate',
  discipline: 'Mechanical Toolkit',
  seedColor: const Color(0xFF455A64),
  tools: mechanicalTools,
  version: kAppVersion,
  aboutText:
      'Everyday calculations for Mechanical and maintenance engineers: bolt torque, belt and gear drives, bearing life, shaft and key sizing, ISO fits, vibration severity and lubrication intervals. Every tool shows its formula, the '
      'standard it follows and worked examples you can load.',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(PlantToolkitApp(config: appConfig, settings: settings));
}
