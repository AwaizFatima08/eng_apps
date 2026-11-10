import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_core/plant_core.dart';
import 'package:plant_core/src/settings.dart' show SettingsScope;
import 'package:plant_core/src/ui/tool_screen.dart';

final _sumTool = ToolDef(
  id: 'sum',
  title: 'Sum of lengths',
  summary: 'Adds a list of lengths.',
  icon: Icons.add,
  inputs: const [
    ListInput(
      'xs',
      'Lengths',
      quantity: Quantity.length,
      initial: [1, 2, 3],
      minCount: 2,
      units: ('m', 'ft'),
    ),
  ],
  compute: (v) => ToolResult([
    ToolOutput(
      'sum',
      'Sum',
      v.l('xs').fold(0.0, (a, b) => a + b),
      quantity: Quantity.length,
      level: OutputLevel.primary,
      units: ('m', 'ft'),
    ),
  ]),
  formula: 'Σx',
  references: const ['arithmetic'],
  cases: const [
    ToolCase(
      'mm list',
      source: 'hand',
      lists: {'xs': ([100, 200, 700], 'mm')},
      expect: {'sum': (1, 'm')},
    ),
  ],
);

void main() {
  test('verifyTool converts list units', () {
    expect(verifyTool(_sumTool).single.failures, isEmpty);
  });

  test('validation counts values', () {
    final v = ToolValues({}, {}, {'xs': [1.0]});
    expect(_sumTool.validate(v)['xs'], contains('at least 2'));
  });

  testWidgets('list field parses spaces, commas and new lines', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: SettingsScope(
          settings: AppSettings.memory(),
          child: ToolScreen(tool: _sumTool),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('6'), findsWidgets);
    await t.enterText(find.byType(TextField), '1.5, 2\n3 4;0.5');
    await t.pump();
    expect(find.text('11'), findsWidgets);
    expect(find.textContaining('5 values'), findsOneWidget);
    await t.enterText(find.byType(TextField), '1 x');
    await t.pump();
    expect(find.textContaining('Numbers only'), findsOneWidget);
  });
}
