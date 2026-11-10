import 'package:flutter_test/flutter_test.dart';
import 'package:torquemate/tools/tools.dart';
import 'package:plant_core/plant_core.dart';

/// Every worked case of every tool must pass — a failure blocks release.
void main() {
  test('7-tool cap and ≥3 cases per tool', () {
    expect(mechanicalTools.length, lessThanOrEqualTo(7));
    for (final t in mechanicalTools) {
      expect(t.cases.length, greaterThanOrEqualTo(3), reason: t.id);
      expect(t.references, isNotEmpty, reason: t.id);
    }
  });

  for (final tool in mechanicalTools) {
    group(tool.title, () {
      for (final outcome in verifyTool(tool)) {
        test(outcome.testCase.name, () {
          expect(
            outcome.failures,
            isEmpty,
            reason: outcome.failures.join('\n'),
          );
        });
      }
    });
  }
}
