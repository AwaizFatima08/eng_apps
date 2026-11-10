import 'package:plant_core/plant_core.dart';

import 'hx_lmtd.dart';
import 'pipe_flow.dart';
import 'pump.dart';
import 'relief_valve.dart';
import 'steam_if97.dart';
import 'tank_volume.dart';
import 'unit_converter.dart';

/// Process Toolkit V1 — hard cap of 7 tools (plan §7).
final List<ToolDef> processTools = [
  pipeFlowTool,
  pumpTool,
  hxLmtdTool,
  steamTool,
  tankVolumeTool,
  reliefValveTool,
  unitConverterTool,
];
