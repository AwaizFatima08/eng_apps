import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'tools/tools.dart';

/// Must match pubspec `version`.
const String kAppVersion = '1.0.0 (1)';

final appConfig = AppConfig(
  appName: 'SafeShift',
  discipline: 'HSE Toolkit',
  seedColor: const Color(0xFFB45309),
  tools: hseTools,
  version: kAppVersion,
  aboutText:
      'Everyday calculations for HSE officers and supervisors: noise dose, heat stress, confined-space ventilation, chemical exposure, fall clearance, extinguisher coverage and incident rates. Every tool shows its formula, the '
      'standard it follows and worked examples you can load.',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(PlantToolkitApp(config: appConfig, settings: settings));
}
