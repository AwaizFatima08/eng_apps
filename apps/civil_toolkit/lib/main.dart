import 'dart:async';

import 'package:flutter/material.dart';
import 'package:plant_ads/plant_ads.dart';
import 'package:plant_core/plant_core.dart';

import 'tools/tools.dart';

/// Must match pubspec `version`.
const String kAppVersion = '1.0.0 (1)';

/// AdMob (homilabs.smc@gmail.com) app "BeamBook" ca-app-pub-2087846699268567~5029188057; the app id is
/// also in AndroidManifest.xml.
const String kBannerAdUnitId = 'ca-app-pub-2087846699268567/3286016499';

final appConfig = AppConfig(
  appName: 'BeamBook',
  discipline: 'Civil Toolkit',
  seedColor: const Color(0xFF8D4E2A),
  tools: civilTools,
  version: kAppVersion,
  privacyUrl: 'https://tools.homilabs.org/privacy#beambook',
  privacyNote:
      'The calculators work offline and the values you enter stay on this '
      'device; there is no account and no analytics. The home screen shows a '
      'banner ad from Google AdMob, which uses the internet and may use your '
      'device\'s advertising ID, with your consent where the law requires it. '
      'Ads never appear on a tool screen. Your unit and theme choices are '
      'stored only on this device.',
  homeBanner: (_) => const PlantBanner(adUnitId: kBannerAdUnitId),
  settingsExtras: PlantAds.settingsRows,
  aboutText:
      'Everyday calculations for Civil and site engineers: beam shear, moment and deflection, concrete quantities, steel section weights, footing sizing, earthwork volumes and coating quantities. Every tool shows its formula, the '
      'standard it follows and worked examples you can load.',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(PlantToolkitApp(config: appConfig, settings: settings));
  unawaited(PlantAds.init());
}
