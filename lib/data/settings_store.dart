import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme preset ids (persisted via [ThemePreset.name]).
enum ThemePreset {
  system('System Dynamic'),
  obsidian('Opal Obsidian'),
  luma('Luma Warm'),
  ambient('Ambient Night'),
  mono('Monochrome Ink');

  const ThemePreset(this.label);

  final String label;

  static ThemePreset fromName(String? name) => ThemePreset.values.firstWhere(
    (p) => p.name == name,
    orElse: () => ThemePreset.system,
  );
}

/// Font choices (persisted via [FontChoice.family]).
enum FontChoice {
  onest('Onest'),
  golos('Golos Text'),
  martianMono('Martian Mono'),
  ibmPlexMono('IBM Plex Mono');

  const FontChoice(this.family);

  final String family;

  static FontChoice fromFamily(String? family) => FontChoice.values.firstWhere(
    (f) => f.family == family,
    orElse: () => FontChoice.onest,
  );
}

/// Whole-app gate threshold (`none` locks nothing, `critical` most).
enum SecurityThreshold { none, open, restricted, critical }

/// Which event gets the automatic system alarm.
enum AlarmMode { first, tag }

/// What `sweep_old_events` does with past days.
enum OldEventPolicy { nothing, backlog, delete }

/// Appearance-only prefs. [ChoraApp] listens to this (and nothing else) to
/// rebuild [MaterialApp], so toggling e.g. "Square cells" never rebuilds it.
class AppearanceSettings extends ChangeNotifier {
  AppearanceSettings(this._prefs);

  final SharedPreferences _prefs;

  ThemePreset get themePreset =>
      ThemePreset.fromName(_prefs.getString('theme_preset'));
  ThemeMode get themeMode {
    return switch (_prefs.getString('theme_mode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  FontChoice get fontChoice =>
      FontChoice.fromFamily(_prefs.getString('font_name'));

  Future<void> setThemePreset(ThemePreset v) async {
    await _prefs.setString('theme_preset', v.name);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    await _prefs.setString('theme_mode', switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  Future<void> setFontChoice(FontChoice v) async {
    await _prefs.setString('font_name', v.family);
    notifyListeners();
  }
}

/// Persisted settings + in-memory unlock state.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs, this.appearance);

  final SharedPreferences _prefs;

  /// Appearance split: the only thing that rebuilds [MaterialApp].
  final AppearanceSettings appearance;

  bool get showRepeat => _prefs.getBool('show_repeat') ?? true;
  bool get fixedCells => _prefs.getBool('fixed_cells') ?? false;

  /// Gating threshold for file security levels.
  SecurityThreshold get securityThreshold {
    return switch (_prefs.getString('security_threshold')) {
      'none' => SecurityThreshold.none,
      'open' => SecurityThreshold.open,
      'restricted' => SecurityThreshold.restricted,
      _ => SecurityThreshold.critical,
    };
  }

  bool get biometricEnabled => _prefs.getBool('biometric_enabled') ?? true;

  List<String> get hiddenProjects =>
      _prefs.getStringList('hidden_projects') ?? const [];

  /// Null = internal app dir.
  String? get rootDirOverride => _prefs.getString('root_dir');

  bool get notifEnabled => _prefs.getBool('notif_enabled') ?? true;

  /// Minutes before the event, 0 = at start.
  int get notifMinutes => _prefs.getInt('notif_minutes') ?? 15;
  bool get autoAlarm => _prefs.getBool('auto_alarm') ?? false;

  AlarmMode get alarmMode =>
      _prefs.getString('alarm_mode') == 'tag' ? AlarmMode.tag : AlarmMode.first;
  int get alarmBeforeMin => _prefs.getInt('alarm_before_min') ?? 30;

  /// Whole-app unlock (threshold `open`).
  bool appUnlocked = false;

  /// rel_path -> true for files unlocked this session.
  final Map<String, bool> fileUnlocked = {};

  static const _secure = FlutterSecureStorage();

  Future<void> _set(String key, Object value) async {
    if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(key, value);
    }
    notifyListeners();
  }

  Future<void> setShowRepeat(bool v) => _set('show_repeat', v);
  Future<void> setFixedCells(bool v) => _set('fixed_cells', v);
  Future<void> setSecurityThreshold(SecurityThreshold v) =>
      _set('security_threshold', v.name);
  Future<void> setBiometricEnabled(bool v) => _set('biometric_enabled', v);
  Future<void> setHiddenProjects(List<String> v) => _set('hidden_projects', v);
  Future<void> setRootDir(String? v) async {
    if (v == null || v.isEmpty) {
      await _prefs.remove('root_dir');
    } else {
      await _prefs.setString('root_dir', v);
    }
    notifyListeners();
  }

  Future<void> setNotifEnabled(bool v) => _set('notif_enabled', v);
  Future<void> setNotifMinutes(int v) => _set('notif_minutes', v);
  Future<void> setAutoAlarm(bool v) => _set('auto_alarm', v);
  Future<void> setAlarmMode(AlarmMode v) => _set('alarm_mode', v.name);
  Future<void> setAlarmBeforeMin(int v) => _set('alarm_before_min', v);
  OldEventPolicy oldEventPolicy(String? name) => OldEventPolicy.values
      .firstWhere((p) => p.name == name, orElse: () => OldEventPolicy.backlog);

  /// True when `fileSecurity` (open|restricted|critical) needs a gate.
  bool needsGate(String fileSecurity) {
    const order = ['none', 'open', 'restricted', 'critical'];
    final threshold = order.indexOf(securityThreshold.name);
    final level = order.indexOf(fileSecurity);
    if (threshold <= 0 || level < 0) return false;
    return level >= threshold;
  }

  Future<bool> hasPin() async => (await _secure.read(key: 'chora_pin')) != null;
  Future<void> setPin(String pin) =>
      _secure.write(key: 'chora_pin', value: pin);
  Future<bool> checkPin(String pin) async =>
      (await _secure.read(key: 'chora_pin')) == pin;
}
