import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'tools/tools.dart';

/// Must match pubspec `version`.
const String kAppVersion = '1.0.0 (1)';

final appConfig = AppConfig(
  appName: 'FlowSheet',
  discipline: 'Process Toolkit',
  seedColor: const Color(0xFF00796B),
  tools: processTools,
  version: kAppVersion,
  aboutText:
      'Everyday calculations for Process engineers: pipe pressure drop, pump head and NPSH, heat-exchanger LMTD, steam properties, tank volumes, relief sizing and unit conversions. Every tool shows its formula, the '
      'standard it follows and worked examples you can load.',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(PlantToolkitApp(config: appConfig, settings: settings));
}
