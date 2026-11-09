import 'package:plant_core/plant_core.dart';

import 'calibration.dart';
import 'control_valve.dart';
import 'dp_level.dart';
import 'orifice_flow.dart';
import 'pressure_converter.dart';
import 'signal_scaler.dart';
import 'temperature_sensors.dart';

/// Instrument Toolkit V1 — hard cap of 7 tools (plan §7).
final List<ToolDef> instrumentTools = [
  signalScalerTool,
  calibrationTool,
  temperatureSensorsTool,
  pressureConverterTool,
  dpLevelTool,
  orificeFlowTool,
  controlValveTool,
];
