import 'dart:io';

import 'package:chora_mobile/app/app_scope.dart';
import 'package:chora_mobile/app/services.dart';
import 'package:chora_mobile/features/settings/settings_screen.dart';
import 'package:chora_mobile/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_backend.dart';

/// Let bridge futures started by the pumped tree finish, then rebuild.
/// Native completions arrive in real time, their continuations in the
/// test zone: alternate both a few times.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }
}

/// Scroll the settings list until [finder] is fully on screen.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.ensureVisible(finder);
  await tester.pump();
}

Future<AppServices> pumpSettings(
  WidgetTester tester, {
  void Function(String root)? seed,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  final services = (await tester.runAsync(testServices))!;
  seed?.call(services.session.root);
  // Tones live in the app theme; the shared harness uses a bare MaterialApp.
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp(
        theme: buildTheme(
          preset: 'ambient',
          brightness: Brightness.dark,
          fontName: 'Onest',
        ),
        home: const SettingsScreen(),
      ),
    ),
  );
  await settle(tester);
  return services;
}

void main() {
  testWidgets('toggling a calendar option persists it', (tester) async {
    final services = await pumpSettings(tester);
    expect(services.settings.squareCells, isFalse);
    await reveal(tester, find.text('Square day cells'));
    await tester.tap(find.text('Square day cells'));
    await tester.pump();
    expect(services.settings.squareCells, isTrue);
  });

  testWidgets('keeping a conflict copy replaces the file', (tester) async {
    const copy = 'notes/todo.sync-conflict-20261101-101010-ABCDEFG.md';
    final services = await pumpSettings(
      tester,
      seed: (root) {
        File('$root/notes/todo.md').writeAsStringSync('mine');
        File('$root/$copy').writeAsStringSync('theirs');
      },
    );
    final root = services.session.root;
    // The list builds the section lazily; its first load starts in the
    // fake test zone and never finishes. A storage write re-runs the load
    // from real async.
    await reveal(tester, find.text('Storage folder'));
    await tester.runAsync(services.storage.seedDemo);
    await settle(tester);
    final keepCopy = find.text('Keep copy');
    await reveal(tester, keepCopy);
    await tester.runAsync(() => tester.tap(keepCopy));
    await settle(tester);

    expect(File('$root/notes/todo.md').readAsStringSync(), 'theirs');
    expect(File('$root/$copy').existsSync(), isFalse);
    expect(find.text('Keep copy'), findsNothing);
    expect(find.text('Kept the conflict copy'), findsOneWidget);
  });

  testWidgets('survives text scale 2.0 on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpSettings(tester);
    await reveal(tester, find.text('Delete past days'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('text size saves on release only, Reset restores 100%', (
    tester,
  ) async {
    final services = await pumpSettings(tester);
    final appearance = services.settings.appearance;
    final slider = find.byType(Slider).first;
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    expect(appearance.textScale, 1.0, reason: 'not saved while dragging');
    await gesture.up();
    await tester.runAsync(() async {});
    await tester.pump();
    expect(appearance.textScale, greaterThan(1.0));

    await tester.tap(find.text('Reset'));
    await tester.runAsync(() async {});
    await tester.pump();
    expect(appearance.textScale, 1.0);
    expect(appearance.uiScale, 1.0);
    expect(find.text('Reset'), findsNothing);
  });
}
