import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torquemate/main.dart';
import 'package:plant_core/plant_core.dart';

void main() {
  testWidgets('disclaimer → home → every tool opens and computes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PlantToolkitApp(config: appConfig, settings: AppSettings.memory()),
    );
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(find.text('TorqueMate'), findsOneWidget);

    for (final tool in appConfig.tools) {
      await tester.scrollUntilVisible(
        find.text(tool.title),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(tool.title));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Results'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Results'), findsOneWidget, reason: tool.id);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await tester.enterText(find.byType(TextField).first, 'bolt');
    await tester.pumpAndSettle();
    expect(find.textContaining('Bolt'), findsOneWidget);
  });
}
