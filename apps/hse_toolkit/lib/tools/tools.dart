import 'package:plant_core/plant_core.dart';

import 'chemical_exposure.dart';
import 'confined_space.dart';
import 'extinguisher.dart';
import 'fall_clearance.dart';
import 'incident_rates.dart';
import 'noise_dose.dart';
import 'wbgt_heat.dart';

/// HSE Toolkit V1 — hard cap of 7 tools (plan §7).
final List<ToolDef> hseTools = [
  noiseDoseTool,
  wbgtHeatTool,
  confinedSpaceTool,
  chemicalExposureTool,
  fallClearanceTool,
  extinguisherTool,
  incidentRatesTool,
];
