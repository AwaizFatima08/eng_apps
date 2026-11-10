import 'package:plant_core/plant_core.dart';

import 'cable_sizing.dart';
import 'earthing.dart';
import 'motor_current.dart';
import 'pf_correction.dart';
import 'solar_sizer.dart';
import 'three_phase_power.dart';
import 'transformer.dart';

/// Electrical Toolkit V1 — hard cap of 7 tools (plan §7).
final List<ToolDef> electricalTools = [
  cableSizingTool,
  motorCurrentTool,
  transformerTool,
  threePhasePowerTool,
  pfCorrectionTool,
  earthingTool,
  solarSizerTool,
];
