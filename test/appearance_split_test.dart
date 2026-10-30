import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('toggling square cells does not rebuild MaterialApp', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final appearance = AppearanceSettings(prefs);
    final store = SettingsStore(prefs, appearance);

    var appearanceNotified = false;
    appearance.addListener(() => appearanceNotified = true);
    var storeNotified = false;
    store.addListener(() => storeNotified = true);

    await store.setShowRepeat(false);
    await store.setFixedCells(true);
    await store.setHiddenProjects(const ['work']);
    await store.setSecurityThreshold(SecurityThreshold.restricted);
    expect(storeNotified, isTrue);
    expect(appearanceNotified, isFalse);

    await appearance.setThemePreset(ThemePreset.luma);
    expect(appearanceNotified, isTrue);
  });

  test('identical presets share a cached ThemeData', () {
    final a = buildTheme(
      preset: 'obsidian',
      brightness: Brightness.dark,
      fontName: 'Onest',
      dynamicScheme: null,
    );
    final b = buildTheme(
      preset: 'obsidian',
      brightness: Brightness.dark,
      fontName: 'Onest',
      dynamicScheme: null,
    );
    expect(identical(a, b), isTrue);
  });
}
