import 'package:plant_core/plant_core.dart';

import 'bearing_life.dart';
import 'belt_gear.dart';
import 'bolt_torque.dart';
import 'grease_interval.dart';
import 'iso_fits.dart';
import 'shaft_key.dart';
import 'vibration_severity.dart';

/// Mechanical Toolkit V1 — hard cap of 7 tools (plan §7).
final List<ToolDef> mechanicalTools = [
  boltTorqueTool,
  beltGearTool,
  bearingLifeTool,
  shaftKeyTool,
  isoFitsTool,
  vibrationSeverityTool,
  greaseIntervalTool,
];
