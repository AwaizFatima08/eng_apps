import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'tools/tools.dart';

/// Must match pubspec `version`.
const String kAppVersion = '1.0.0 (1)';

final appConfig = AppConfig(
  appName: 'LoopCal',
  discipline: 'Instrument Toolkit',
  seedColor: const Color(0xFF00658F),
  tools: instrumentTools,
  version: kAppVersion,
  aboutText:
      'Everyday calculations for instrument and control engineers and '
      'technicians: loop scaling, calibration checks, sensor tables, level '
      'ranging, orifice flow and control-valve sizing. Every tool shows its '
      'formula, the standard it follows and worked examples you can load.',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(PlantToolkitApp(config: appConfig, settings: settings));
}
