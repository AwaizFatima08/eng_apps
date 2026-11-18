// Renders the Play Store phone screenshots from the real screens.
// Not part of `flutter test`. Run from the repo root:
//   FLUTTER_ROOT=... python3 tool/make_store_fonts.py build/store_fonts
// then in apps/electrical_toolkit:
//   STORE_FONTS=../../build/store_fonts flutter test test_store --update-goldens
// and copy test_store/out/*.png to store/screenshots/. FONT_SCALE=1.15 renders
// the same screens at a large phone font size for layout review.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_core/plant_core.dart';
import 'package:voltwise/main.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
    );
  }
  await loader.load();
}

final _scale = double.tryParse(Platform.environment['FONT_SCALE'] ?? '') ?? 1;
final _prefix = _scale == 1 ? '' : 'scale_';

Future<void> _pumpApp(WidgetTester tester) async {
  // 1080×1920 phone (Play needs 9:16 or narrower).
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.625;
  tester.platformDispatcher.textScaleFactorTestValue = _scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final settings = AppSettings.memory()..acceptDisclaimer();
  await tester.pumpWidget(
    PlantToolkitApp(config: appConfig, settings: settings),
  );
  await tester.pumpAndSettle();
}

Finder get _vertical => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

Future<void> _open(WidgetTester tester, String title) async {
  final finder = find.text(title);
  await tester.scrollUntilVisible(finder, 150, scrollable: _vertical);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls the tool screen so [text] sits near the top.
Future<void> _scrollTo(WidgetTester tester, String text) async {
  final finder = find.text(text);
  // The tool screen's list is the last vertical scrollable (the home list
  // stays in the tree behind it).
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.02);
  await tester.pumpAndSettle();
}

Future<void> _shot(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('out/$_prefix$name.png'),
);

void main() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final icons = '$flutterRoot/bin/cache/artifacts/material_fonts';

  setUpAll(() async {
    // Roboto plus subscripts and arrows from tool/make_store_fonts.py: the
    // test engine has no font fallback.
    final merged = Platform.environment['STORE_FONTS']!;
    await _loadFont('Roboto', [
      '$merged/Roboto-Regular.ttf',
      '$merged/Roboto-Medium.ttf',
      '$merged/Roboto-Bold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$icons/MaterialIcons-Regular.otf']);
  });

  testWidgets('1 home', (tester) async {
    await _pumpApp(tester);
    await _shot('1_home');
  });

  testWidgets('2 cable_sizing', (tester) async {
    await _pumpApp(tester);
    await _open(tester, 'Cable sizing & voltage drop');
    await _shot('2_cable_sizing');
  });

  testWidgets('3 cable_results', (tester) async {
    await _pumpApp(tester);
    await _open(tester, 'Cable sizing & voltage drop');
    await _scrollTo(tester, 'Results');
    await _shot('3_cable_results');
  });

  testWidgets('4 motor', (tester) async {
    await _pumpApp(tester);
    await _open(tester, 'Motor current & starter');
    await _scrollTo(tester, 'Results');
    await _shot('4_motor');
  });

  testWidgets('5 transformer', (tester) async {
    await _pumpApp(tester);
    await _open(tester, 'Transformer current & fault level');
    await _scrollTo(tester, 'Results');
    await _shot('5_transformer');
  });

  testWidgets('6 solar', (tester) async {
    await _pumpApp(tester);
    await _open(tester, 'Solar array & battery sizer');
    await _scrollTo(tester, 'Results');
    await _shot('6_solar');
  });
}
