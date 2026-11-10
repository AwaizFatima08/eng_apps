import 'package:plant_core/plant_core.dart';

import 'beam.dart';
import 'coating.dart';
import 'concrete_mix.dart';
import 'earthwork.dart';
import 'footing.dart';
import 'steel_weight.dart';

/// Civil Toolkit V1 — hard cap of 7 tools (plan §7).
final List<ToolDef> civilTools = [
  beamTool,
  concreteMixTool,
  steelWeightTool,
  footingTool,
  earthworkTool,
  coatingTool,
];
