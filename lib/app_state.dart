import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted settings + in-memory unlock state.
class AppState extends ChangeNotifier {
  AppState(this._prefs);

  final SharedPreferences _prefs;
  static const _secure = FlutterSecureStorage();

  static const presetSystem = 'system';
  static const presetObsidian = 'obsidian';
  static const presetLuma = 'luma';
  static const presetMono = 'mono';

  String get themePreset => _prefs.getString('theme_preset') ?? presetSystem;
  ThemeMode get themeMode {
    return switch (_prefs.getString('theme_mode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String get fontName => _prefs.getString('font_name') ?? 'Onest';
  bool get showRepeat => _prefs.getBool('show_repeat') ?? true;
  bool get fixedCells => _prefs.getBool('fixed_cells') ?? false;

  /// none | open | restricted | critical
  String get securityThreshold =>
      _prefs.getString('security_threshold') ?? 'critical';
  bool get biometricEnabled => _prefs.getBool('biometric_enabled') ?? true;

  List<String> get hiddenProjects =>
      _prefs.getStringList('hidden_projects') ?? const [];

  /// Null = internal app dir.
  String? get rootDirOverride => _prefs.getString('root_dir');

  bool get notifEnabled => _prefs.getBool('notif_enabled') ?? true;

  /// Minutes before the event, 0 = at start.
  int get notifMinutes => _prefs.getInt('notif_minutes') ?? 15;
  bool get autoAlarm => _prefs.getBool('auto_alarm') ?? false;

  /// first | tag
  String get alarmMode => _prefs.getString('alarm_mode') ?? 'first';
  int get alarmBeforeMin => _prefs.getInt('alarm_before_min') ?? 30;

  /// Whole-app unlock (threshold `open`).
  bool appUnlocked = false;

  /// rel_path -> true for files unlocked this session.
  final Map<String, bool> fileUnlocked = {};

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

  Future<void> setThemePreset(String v) => _set('theme_preset', v);
  Future<void> setThemeMode(ThemeMode m) => _set('theme_mode', switch (m) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  });
  Future<void> setFontName(String v) => _set('font_name', v);
  Future<void> setShowRepeat(bool v) => _set('show_repeat', v);
  Future<void> setFixedCells(bool v) => _set('fixed_cells', v);
  Future<void> setSecurityThreshold(String v) => _set('security_threshold', v);
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
  Future<void> setAlarmMode(String v) => _set('alarm_mode', v);
  Future<void> setAlarmBeforeMin(int v) => _set('alarm_before_min', v);

  /// True when `fileSecurity` (open|restricted|critical) needs a gate.
  bool needsGate(String fileSecurity) {
    const order = ['none', 'open', 'restricted', 'critical'];
    final threshold = order.indexOf(securityThreshold);
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
