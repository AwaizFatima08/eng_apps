import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'tools/tools.dart';

/// Must match pubspec `version`.
const String kAppVersion = '1.0.0 (1)';

final appConfig = AppConfig(
  appName: 'BeamBook',
  discipline: 'Civil Toolkit',
  seedColor: const Color(0xFF8D4E2A),
  tools: civilTools,
  version: kAppVersion,
  aboutText:
      'Everyday calculations for Civil and site engineers: beam shear, moment and deflection, concrete quantities, steel section weights, footing sizing, earthwork volumes and coating quantities. Every tool shows its formula, the '
      'standard it follows and worked examples you can load.',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(PlantToolkitApp(config: appConfig, settings: settings));
}
