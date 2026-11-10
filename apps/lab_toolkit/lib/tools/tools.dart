import 'package:plant_core/plant_core.dart';

import 'concentration.dart';
import 'density_temp.dart';
import 'dilution.dart';
import 'moisture.dart';
import 'statistics.dart';
import 'titration.dart';
import 'water_quality.dart';

/// Lab Toolkit V1 — hard cap of 7 tools (plan §7).
final List<ToolDef> labTools = [
  dilutionTool,
  concentrationTool,
  titrationTool,
  densityTempTool,
  moistureTool,
  statisticsTool,
  waterQualityTool,
];
