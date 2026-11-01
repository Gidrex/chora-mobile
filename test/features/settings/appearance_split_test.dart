import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/domain/security.dart';
import 'package:chora_mobile/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'non-appearance settings never notify the MaterialApp listener',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SettingsStore(await SharedPreferences.getInstance());
      // ChoraApp rebuilds MaterialApp only from `store.appearance`.
      var appearanceNotified = false;
      store.appearance.addListener(() => appearanceNotified = true);
      var storeNotified = false;
      store.addListener(() => storeNotified = true);

      await store.setShowWeekly(false);
      await store.setSquareCells(true);
      await store.setHiddenProjects(const ['work']);
      await store.setSecurityThreshold(SecurityThreshold.restricted);
      expect(storeNotified, isTrue);
      expect(appearanceNotified, isFalse);

      await store.appearance.setThemePreset(ThemePreset.luma);
      expect(appearanceNotified, isTrue);
    },
  );

  test('identical presets share a cached ThemeData', () {
    ThemeData build() => buildTheme(
      preset: 'obsidian',
      brightness: Brightness.dark,
      fontName: 'Onest',
      dynamicScheme: null,
    );
    expect(identical(build(), build()), isTrue);
  });
}
