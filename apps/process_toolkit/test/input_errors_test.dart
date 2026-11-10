import 'package:flowsheet/tools/hx_lmtd.dart';
import 'package:flowsheet/tools/relief_valve.dart';
import 'package:flowsheet/tools/steam_if97.dart';
import 'package:flowsheet/tools/tank_volume.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_core/plant_core.dart';

/// Impossible inputs must raise ToolInputError, never a silent number.
ToolResult _run(
  ToolDef t,
  Map<String, double> n, [
  Map<String, String> c = const {},
]) {
  final b = t.initialValues();
  return t.compute(ToolValues({...b.numbers, ...n}, {...b.choices, ...c}));
}

void main() {
  final err = throwsA(isA<ToolInputError>());
  test('HX: 1-2 shell cannot reach R = 1, P = 0.667', () {
    expect(
      () => _run(
        hxLmtdTool,
        {'thi': 200, 'tho': 100, 'tci': 50, 'tco': 150},
        {'arr': 's12'},
      ),
      err,
    );
  });
  test('HX: counter-current temperature cross', () {
    expect(
      () => _run(hxLmtdTool, {'thi': 100, 'tho': 40, 'tci': 50, 'tco': 120}),
      err,
    );
  });
  test('Steam: region 3 and saturation above 350 °C are refused', () {
    expect(() => _run(steamTool, {'p': 300e5, 't': 400}), err);
    expect(() => _run(steamTool, {'t': 360}, {'mode': 'satT'}), err);
    expect(() => _run(steamTool, {'p': 200e5}, {'mode': 'satP'}), err);
  });
  test('Tank: level above the top is refused', () {
    expect(() => _run(tankVolumeTool, {'h': 7}), err);
  });
  test('Relief: back pressure at relieving pressure is refused', () {
    expect(() => _run(reliefValveTool, {'pb': 12e5}), err);
  });
}
