import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'tools/tools.dart';

/// Must match pubspec `version`.
const String kAppVersion = '1.0.0 (1)';

final appConfig = AppConfig(
  appName: 'VoltWise',
  discipline: 'Electrical Toolkit',
  seedColor: const Color(0xFF3949AB),
  tools: electricalTools,
  version: kAppVersion,
  aboutText:
      'Everyday calculations for Electrical engineers and technicians: cable sizing and voltage drop, motor current, transformers, three-phase power, power-factor correction, earthing and solar/battery sizing. Every tool shows its formula, the '
      'standard it follows and worked examples you can load.',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(PlantToolkitApp(config: appConfig, settings: settings));
}
