import 'dart:io';

import 'package:chora_mobile/app/app_scope.dart';
import 'package:chora_mobile/app/services.dart';
import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/data/vault_session.dart';
import 'package:chora_mobile/domain/reminders.dart';
import 'package:chora_mobile/platform/notifications.dart';
import 'package:chora_mobile/ui/theme.dart';
import 'package:chora_mobile/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;
import 'package:shared_preferences/shared_preferences.dart';

bool _ready = false;

/// Real backend over a fresh temp storage. `flutter test` does not bundle
/// the Rust lib: run `cargo build` in `rust/` after any bridge change.
/// Call inside `tester.runAsync` in widget tests (bridge futures need it).
Future<AppServices> testServices({Map<String, Object> prefs = const {}}) async {
  if (!_ready) {
    const so = 'rust/target/debug/libchora_mobile_rust.so';
    if (!File(so).existsSync()) {
      throw StateError('missing $so: run `cargo build` in rust/ first');
    }
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(File(so).absolute.path),
    );
    _ready = true;
  }
  SharedPreferences.setMockInitialValues(prefs);
  final tmp = await Directory.systemTemp.createTemp('chora_test');
  return AppServices(
    settings: SettingsStore(await SharedPreferences.getInstance()),
    session: await VaultSession.open(tmp.path),
    notifier: SilentNotifier(),
  );
}

/// Records instead of talking to Android notifications.
class SilentNotifier implements Notifier {
  final planned = <List<PlannedReminder>>[];
  final alarms = <DateTime>[];

  @override
  Future<void> replaceAll(List<PlannedReminder> plan) async =>
      planned.add(plan);

  @override
  Future<void> setAlarm({required String title, required DateTime at}) async =>
      alarms.add(at);
}

/// [child] under [AppScope] and a [MaterialApp], as in the running app.
Widget harness(AppServices services, Widget child) => AppScope(
  services: services,
  child: MaterialApp(
    theme: buildTheme(
      preset: services.settings.appearance.themePreset.name,
      brightness: Brightness.dark,
      fontName: 'Onest',
    ),
    home: child,
  ),
);
