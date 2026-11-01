import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reminders.dart';
import '../domain/security.dart';

/// Color presets (persisted by [name]).
enum ThemePreset {
  system('System colors'),
  obsidian('Opal Obsidian'),
  luma('Luma Warm'),
  ambient('Ambient Night'),
  mono('Monochrome Ink');

  const ThemePreset(this.label);

  final String label;
}

/// Bundled font families (persisted by [family]).
enum FontChoice {
  onest('Onest'),
  golos('Golos Text'),
  martianMono('Martian Mono'),
  ibmPlexMono('IBM Plex Mono');

  const FontChoice(this.family);

  final String family;
}

/// How the Events tab shows days.
enum EventsView { month, agenda }

T _byName<T extends Enum>(List<T> values, String? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

/// Appearance prefs. The app root listens to this (and nothing else) to
/// rebuild [MaterialApp].
class AppearanceSettings extends ChangeNotifier {
  AppearanceSettings(this._prefs);

  final SharedPreferences _prefs;

  ThemePreset get themePreset => _byName(
    ThemePreset.values,
    _prefs.getString('theme_preset'),
    ThemePreset.system,
  );

  ThemeMode get themeMode => _byName(
    ThemeMode.values,
    _prefs.getString('theme_mode'),
    ThemeMode.system,
  );

  FontChoice get fontChoice => FontChoice.values.firstWhere(
    (f) => f.family == _prefs.getString('font_name'),
    orElse: () => FontChoice.onest,
  );

  /// Text size multiplier on top of the system setting.
  double get textScale => _prefs.getDouble('text_scale') ?? 1.0;

  /// Whole-UI zoom (layout, icons and text together).
  double get uiScale => _prefs.getDouble('ui_scale') ?? 1.0;

  static const textScaleRange = (min: 0.8, max: 1.6);
  static const uiScaleRange = (min: 0.8, max: 1.3);

  Future<void> setTextScale(double v) => _save(
    () => _prefs.setDouble(
      'text_scale',
      v.clamp(textScaleRange.min, textScaleRange.max),
    ),
  );
  Future<void> setUiScale(double v) => _save(
    () => _prefs.setDouble(
      'ui_scale',
      v.clamp(uiScaleRange.min, uiScaleRange.max),
    ),
  );

  Future<void> setThemePreset(ThemePreset v) =>
      _save(() => _prefs.setString('theme_preset', v.name));
  Future<void> setThemeMode(ThemeMode v) =>
      _save(() => _prefs.setString('theme_mode', v.name));
  Future<void> setFontChoice(FontChoice v) =>
      _save(() => _prefs.setString('font_name', v.family));

  Future<void> _save(Future<bool> Function() write) async {
    await write();
    notifyListeners();
  }
}

/// Every persisted preference except appearance. Keys are stable across
/// versions; never rename one without a migration.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs) : appearance = AppearanceSettings(_prefs);

  final SharedPreferences _prefs;
  final AppearanceSettings appearance;

  /// Null = the app's private folder.
  String? get storagePath => _prefs.getString('root_dir');

  bool get showWeekly => _prefs.getBool('show_repeat') ?? true;
  bool get squareCells => _prefs.getBool('fixed_cells') ?? false;
  EventsView get eventsView => _byName(
    EventsView.values,
    _prefs.getString('events_view'),
    EventsView.month,
  );

  SecurityThreshold get securityThreshold => _byName(
    SecurityThreshold.values,
    _prefs.getString('security_threshold'),
    SecurityThreshold.critical,
  );
  bool get biometricEnabled => _prefs.getBool('biometric_enabled') ?? true;

  List<String> get hiddenProjects =>
      _prefs.getStringList('hidden_projects') ?? const [];

  bool get remindersEnabled => _prefs.getBool('notif_enabled') ?? true;

  /// Minutes before an event; 0 = at the start.
  int get reminderMinutes => _prefs.getInt('notif_minutes') ?? 15;

  bool get autoAlarm => _prefs.getBool('auto_alarm') ?? false;
  AlarmMode get alarmMode => _byName(
    AlarmMode.values,
    _prefs.getString('alarm_mode'),
    AlarmMode.first,
  );
  int get alarmMinutes => _prefs.getInt('alarm_before_min') ?? 30;

  Future<void> setStoragePath(String? v) => v == null || v.isEmpty
      ? _save(() => _prefs.remove('root_dir'))
      : _save(() => _prefs.setString('root_dir', v));
  Future<void> setShowWeekly(bool v) =>
      _save(() => _prefs.setBool('show_repeat', v));
  Future<void> setSquareCells(bool v) =>
      _save(() => _prefs.setBool('fixed_cells', v));
  Future<void> setEventsView(EventsView v) =>
      _save(() => _prefs.setString('events_view', v.name));
  Future<void> setSecurityThreshold(SecurityThreshold v) =>
      _save(() => _prefs.setString('security_threshold', v.name));
  Future<void> setBiometricEnabled(bool v) =>
      _save(() => _prefs.setBool('biometric_enabled', v));
  Future<void> setHiddenProjects(List<String> v) =>
      _save(() => _prefs.setStringList('hidden_projects', v));
  Future<void> setRemindersEnabled(bool v) =>
      _save(() => _prefs.setBool('notif_enabled', v));
  Future<void> setReminderMinutes(int v) =>
      _save(() => _prefs.setInt('notif_minutes', v));
  Future<void> setAutoAlarm(bool v) =>
      _save(() => _prefs.setBool('auto_alarm', v));
  Future<void> setAlarmMode(AlarmMode v) =>
      _save(() => _prefs.setString('alarm_mode', v.name));
  Future<void> setAlarmMinutes(int v) =>
      _save(() => _prefs.setInt('alarm_before_min', v));

  Future<void> _save(Future<bool> Function() write) async {
    await write();
    notifyListeners();
  }
}
