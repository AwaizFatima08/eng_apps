import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tool.dart';
import 'units.dart';

/// Per-app branding and content. Each toolkit app passes one of these to
/// [PlantToolkitApp]; a merged suite can later pass several.
class AppConfig {
  const AppConfig({
    required this.appName,
    required this.discipline,
    required this.seedColor,
    required this.tools,
    required this.version,
    required this.aboutText,
    this.privacyUrl,
  });

  /// Launcher / store name, e.g. "LoopCal".
  final String appName;

  /// Discipline line, e.g. "Instrument Toolkit".
  final String discipline;
  final Color seedColor;
  final List<ToolDef> tools;

  /// "1.0.0 (1)"
  final String version;
  final String aboutText;
  final String? privacyUrl;
}

/// User preferences, persisted with shared_preferences.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  static Future<AppSettings> load() async {
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {
      p = null; // tests / unavailable storage: run with defaults
    }
    return AppSettings._(p);
  }

  /// In-memory settings for widget tests.
  AppSettings.memory() : _prefs = null;

  final SharedPreferences? _prefs;

  static const _kSystem = 'unitSystem';
  static const _kTheme = 'themeMode';
  static const _kDisclaimer = 'disclaimerAccepted.v1';

  UnitSystem get unitSystem =>
      UnitSystem.values.asNameMap()[_prefs?.getString(_kSystem)] ??
      _memSystem ??
      UnitSystem.metric;

  set unitSystem(UnitSystem s) {
    _prefs?.setString(_kSystem, s.name);
    _memSystem = s;
    notifyListeners();
  }

  ThemeMode get themeMode =>
      ThemeMode.values.asNameMap()[_prefs?.getString(_kTheme)] ??
      _memTheme ??
      ThemeMode.system;

  set themeMode(ThemeMode m) {
    _prefs?.setString(_kTheme, m.name);
    _memTheme = m;
    notifyListeners();
  }

  bool get disclaimerAccepted =>
      _prefs?.getBool(_kDisclaimer) ?? _memDisclaimer;

  void acceptDisclaimer() {
    _prefs?.setBool(_kDisclaimer, true);
    _memDisclaimer = true;
    notifyListeners();
  }

  // Fallbacks when no preferences store is present.
  UnitSystem? _memSystem;
  ThemeMode? _memTheme;
  bool _memDisclaimer = false;
}

class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}

class ConfigScope extends InheritedWidget {
  const ConfigScope({super.key, required this.config, required super.child});
  final AppConfig config;

  static AppConfig of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConfigScope>()!.config;

  @override
  bool updateShouldNotify(ConfigScope old) => old.config != config;
}
